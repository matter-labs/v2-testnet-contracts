// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "./Base.sol";
import "../Config.sol";
import "../interfaces/IExecutor.sol";
import "../libraries/PriorityQueue.sol";
import "../../common/libraries/UnsafeBytes.sol";
import "../../common/L2ContractHelper.sol";

/// @title zkSync Executor contract capable of processing events emitted in the zkSync protocol.
/// @author Matter Labs
contract ExecutorFacet is Base, IExecutor {
    using PriorityQueue for PriorityQueue.Queue;

    /// @dev Process one block commit using the previous block StoredBlockInfo
    /// @dev returns new block StoredBlockInfo
    /// @notice Does not change storage
    function _commitOneBlock(StoredBlockInfo memory _previousBlock, CommitBlockInfo calldata _newBlock)
        internal
        view
        returns (StoredBlockInfo memory storedNewBlock)
    {
        require(_newBlock.blockNumber == _previousBlock.blockNumber + 1, "f"); // only commit next block

        // Check that block contain all meta information for L2 logs.
        // Get the chained hash of priority transaction hashes.
        (bytes32 priorityOperationsHash, bytes32 previousBlockHash, uint256 blockTimestamp) = _processL2Logs(_newBlock);

        require(_previousBlock.blockHash == previousBlockHash, "l");

        // Preventing "stack too deep error"
        {
            // Check the timestamp of the new block
            bool timestampNotTooSmall = block.timestamp - COMMIT_TIMESTAMP_NOT_OLDER <= blockTimestamp;
            bool timestampNotTooBig = blockTimestamp <= block.timestamp + COMMIT_TIMESTAMP_APPROXIMATION_DELTA;
            require(timestampNotTooSmall && timestampNotTooBig, "h"); // New block timestamp is not valid

            // Check the index of repeated storage writes
            uint256 newStorageChangesIndexes = uint256(uint32(bytes4(_newBlock.initialStorageChanges[:4])));
            require(
                _previousBlock.indexRepeatedStorageChanges + newStorageChangesIndexes ==
                    _newBlock.indexRepeatedStorageChanges,
                "yq"
            );
        }

        bytes32 blockHash = _calculateBlockHash(_previousBlock, _newBlock);

        // Create block commitment for the proof verification
        bytes32 commitment = _createBlockCommitment(_newBlock, blockHash);

        return
            StoredBlockInfo(
                _newBlock.blockNumber,
                blockHash,
                _newBlock.indexRepeatedStorageChanges,
                _newBlock.numberOfLayer1Txs,
                priorityOperationsHash,
                _newBlock.l2LogsTreeRoot,
                _newBlock.timestamp,
                commitment
            );
    }

    function _calculateBlockHash(StoredBlockInfo memory _previousBlock, CommitBlockInfo calldata _newBlock)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_previousBlock.blockHash, _newBlock.newStateRoot));
    }

    /// @dev Check that L2 logs are proper and block contain all meta information for them
    function _processL2Logs(CommitBlockInfo calldata _newBlock)
        internal
        pure
        returns (
            bytes32 chainedPriorityTxsHash,
            bytes32 previousBlockHash,
            uint256 blockTimestamp
        )
    {
        // Copy L2 to L1 logs into memory.
        bytes memory emmitedL2Logs = _newBlock.l2Logs[4:];
        bytes[] calldata l2Messages = _newBlock.l2ArbitraryLengthMessages;
        uint256 currentMessage;
        bytes[] calldata factoryDeps = _newBlock.factoryDeps;
        uint256 currentBytecode;

        chainedPriorityTxsHash = EMPTY_STRING_KECCAK;

        // linear traversal of the logs
        uint256 emmitedL2LogsLen = emmitedL2Logs.length;
        for (uint256 i = 0; i < emmitedL2LogsLen; ) {
            (address logSender, ) = UnsafeBytes.readAddress(emmitedL2Logs, i + 4);

            // show preimage for hashed message stored in log
            if (logSender == L2_TO_L1_MESSENGER) {
                (bytes32 hashedMessage, ) = UnsafeBytes.readBytes32(emmitedL2Logs, i + 56);
                require(keccak256(l2Messages[currentMessage]) == hashedMessage, "k2");

                unchecked {
                    ++currentMessage;
                }
            } else if (logSender == L2_BOOTLOADER_ADDRESS) {
                (bytes32 canonicalTxHash, ) = UnsafeBytes.readBytes32(emmitedL2Logs, i + 24);
                chainedPriorityTxsHash = keccak256(bytes.concat(chainedPriorityTxsHash, canonicalTxHash));
            } else if (logSender == L2_SYSTEM_CONTEXT_ADDRESS) {
                (blockTimestamp, ) = UnsafeBytes.readUint256(emmitedL2Logs, i + 24);
                (previousBlockHash, ) = UnsafeBytes.readBytes32(emmitedL2Logs, i + 56);
            } else if (logSender == L2_KNOWN_CODE_STORAGE_ADDRESS) {
                (bytes32 bytecodeHash, ) = UnsafeBytes.readBytes32(emmitedL2Logs, i + 24);
                require(bytecodeHash == L2ContractHelper.hashL2Bytecode(factoryDeps[currentBytecode]), "k3");

                unchecked {
                    ++currentBytecode;
                }
            }

            // move the pointer to the next log
            unchecked {
                i += L2_TO_L1_LOG_SERIALIZE_SIZE;
            }
        }
    }

    /// @notice Commit block
    /// @notice 1. Checks timestamp.
    /// @notice 2. Process L2 logs.
    /// @notice 3. Store block commitments.
    function commitBlocks(StoredBlockInfo memory _lastCommittedBlockData, CommitBlockInfo[] calldata _newBlocksData)
        external
        override
        nonReentrant
        onlyValidator
    {
        // Check that we commit blocks after last committed block
        require(s.storedBlockHashes[s.totalBlocksCommitted] == _hashStoredBlockInfo(_lastCommittedBlockData), "i"); // incorrect previous block data

        uint256 blocksLength = _newBlocksData.length;
        for (uint256 i = 0; i < blocksLength; ) {
            _lastCommittedBlockData = _commitOneBlock(_lastCommittedBlockData, _newBlocksData[i]);
            s.storedBlockHashes[_lastCommittedBlockData.blockNumber] = _hashStoredBlockInfo(_lastCommittedBlockData);
            emit BlockCommit(_lastCommittedBlockData.blockNumber);

            unchecked {
                ++i;
            }
        }

        s.totalBlocksCommitted = s.totalBlocksCommitted + blocksLength;
    }

    /// @dev Pops the priority operations from the priority queue and returns a rolling hash of operations
    function _collectOperationsFromPriorityQueue(uint256 _nPriorityOps) internal returns (bytes32 concatHash) {
        concatHash = EMPTY_STRING_KECCAK;

        for (uint256 i = 0; i < _nPriorityOps; ) {
            PriorityOperation memory priorityOp = s.priorityQueue.popFront();
            concatHash = keccak256(abi.encodePacked(concatHash, priorityOp.canonicalTxHash));

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Executes one block
    /// @dev 1. Processes all pending operations (Send Exits, Complete priority requests)
    /// @dev 2. Finalizes block on Ethereum
    /// @dev _executedBlockIdx is an index in the array of the blocks that we want to execute together
    function _executeOneBlock(StoredBlockInfo memory _storedBlock, uint256 _executedBlockIdx) internal {
        uint256 currentBlockNumber = _storedBlock.blockNumber;
        require(currentBlockNumber == s.totalBlocksExecuted + _executedBlockIdx + 1, "k"); // Execute blocks in order
        require(
            _hashStoredBlockInfo(_storedBlock) == s.storedBlockHashes[currentBlockNumber],
            "exe10" // executing block should be committed
        );

        bytes32 priorityOperationsHash = _collectOperationsFromPriorityQueue(_storedBlock.numberOfLayer1Txs);
        require(priorityOperationsHash == _storedBlock.priorityOperationsHash, "x"); // priority operations hash does not match to expected

        // Save root hash of L2 -> L1 logs tree
        s.l2LogsRootHashes[currentBlockNumber] = _storedBlock.l2LogsTreeRoot;
    }

    /// @notice Execute blocks, complete priority operations and process withdrawals.
    /// @notice 1. Processes all pending operations (Send Exits, Complete priority requests)
    /// @notice 2. Finalizes block on Ethereum
    function executeBlocks(StoredBlockInfo[] calldata _blocksData) external nonReentrant onlyValidator {
        uint256 nBlocks = _blocksData.length;
        for (uint256 i = 0; i < nBlocks; ) {
            _executeOneBlock(_blocksData[i], i);
            emit BlockExecution(_blocksData[i].blockNumber);

            unchecked {
                ++i;
            }
        }

        s.totalBlocksExecuted = s.totalBlocksExecuted + nBlocks;
        require(s.totalBlocksExecuted <= s.totalBlocksVerified, "n"); // Can't execute blocks more then committed and proven currently.
    }

    /// @notice Blocks commitment verification.
    /// @notice Only verifies block commitments without any other processing
    function proveBlocks(StoredBlockInfo[] calldata _committedBlocks, ProofInput memory _proof) external nonReentrant {
        uint256 i;
        uint256 currentTotalBlocksVerified = s.totalBlocksVerified;

        // Ignoring the `_committedBlocks` which are already proved.
        bytes32 firstUnverifiedBlockHash = s.storedBlockHashes[currentTotalBlocksVerified + 1];
        while (_hashStoredBlockInfo(_committedBlocks[i]) != firstUnverifiedBlockHash) {
            unchecked {
                ++i;
            }
        }

        // Check that all other blocks are committed and have the same commitment as `_proof`.
        while (i < _committedBlocks.length) {
            require(
                _hashStoredBlockInfo(_committedBlocks[i]) == s.storedBlockHashes[currentTotalBlocksVerified + 1],
                "o1"
            );
            // TODO: restore after verifier will be integrated
            // require(_proof.commitments[i] & INPUT_MASK == uint256(_committedBlocks[i].commitment) & INPUT_MASK, "o"); // incorrect block commitment in proof

            unchecked {
                ++i;
                ++currentTotalBlocksVerified;
            }
        }

        bool success = s.verifier.verifyAggregatedBlockProof(
            _proof.recursiveInput,
            _proof.proof,
            _proof.vkIndexes,
            _proof.commitments,
            _proof.subproofsLimbs
        );
        require(success, "p"); // Aggregated proof verification fail

        require(currentTotalBlocksVerified <= s.totalBlocksCommitted, "q");
        s.totalBlocksVerified = currentTotalBlocksVerified;
    }

    /// @notice Reverts unexecuted blocks
    /// @param _newLastBlock block number after which blocks should be reverted
    /// NOTE: Doesn't delete the stored data about blocks, but only decreases
    /// counters that are responsible for the number of blocks
    function revertBlocks(uint256 _newLastBlock) external nonReentrant onlyValidator {
        require(s.totalBlocksCommitted > _newLastBlock, "v1"); // the last committed block is less new last block
        s.totalBlocksCommitted = _maxU256(_newLastBlock, s.totalBlocksExecuted);

        if (s.totalBlocksCommitted < s.totalBlocksVerified) {
            s.totalBlocksVerified = s.totalBlocksCommitted;
        }

        emit BlocksRevert(s.totalBlocksCommitted, s.totalBlocksVerified, s.totalBlocksExecuted);
    }

    /// @notice Returns larger of two values
    function _maxU256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? b : a;
    }

    /// @dev Creates block commitment from its data
    function _createBlockCommitment(CommitBlockInfo calldata _newBlockData, bytes32 _blockHash)
        internal
        view
        returns (bytes32)
    {
        bytes32 passThroughDataHash = keccak256(_blockPassThroughData(_newBlockData, _blockHash));
        bytes32 metadataHash = keccak256(_blockMetaParameters(_newBlockData));
        bytes32 auxiliaryOutputHash = keccak256(_blockAuxilaryOutput(_newBlockData));

        return keccak256(abi.encode(passThroughDataHash, metadataHash, auxiliaryOutputHash));
    }

    function _blockPassThroughData(CommitBlockInfo calldata _block, bytes32 _blockHash)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodePacked(
                _block.indexRepeatedStorageChanges,
                _blockHash,
                uint64(0), // index repeated storage changes in zkPorter
                bytes32(0) // zkPorter block hash
            );
    }

    function _blockMetaParameters(CommitBlockInfo calldata _block) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                _block.ergsPerCodeDecommittmentWord,
                s.zkPorterIsAvailable,
                s.l2BootloaderBytecodeHash,
                s.l2DefaultAccountBytecodeHash
            );
    }

    function _blockAuxilaryOutput(CommitBlockInfo calldata _block) internal pure returns (bytes memory) {
        bytes32 initialStorageChangesHash = _hashPaddedData(
            _block.initialStorageChanges,
            INITIAL_STORAGE_CHANGES_COMMITMENT_BYTES
        );
        bytes32 repeatedStorageChangesHash = _hashPaddedData(
            _block.repeatedStorageChanges,
            REPEATED_STORAGE_CHANGES_COMMITMENT_BYTES
        );
        bytes32 l2ToL1LogsHash = _hashPaddedData(_block.l2Logs, L2_TO_L1_LOGS_COMMITMENT_BYTES);

        return abi.encode(_block.l2LogsTreeRoot, l2ToL1LogsHash, initialStorageChangesHash, repeatedStorageChangesHash);
    }

    function _hashPaddedData(bytes calldata _data, uint256 _paddedLength) internal pure returns (bytes32 result) {
        uint256 actualLength = _data.length;
        require(_paddedLength >= actualLength, "gy");

        assembly {
            // The pointer to the free memory slot.
            let ptr := mload(0x40)
            // Copy payload data from "calldata" to "memory".
            calldatacopy(ptr, _data.offset, actualLength)
            // Pad it with zeros on the right side.
            // Copy calldata in memory that go beyond the calldata size, according to the Appendix H in the
            // Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf) zero bytes will be copied into memory.
            calldatacopy(add(ptr, actualLength), calldatasize(), sub(_paddedLength, actualLength))

            // We don't change the free memory pointer, since the data we store is only needed to calculate a hash.
            // It doesn't break current solidity (<= 0.8.x) invariants.

            result := keccak256(ptr, _paddedLength)
        }
    }

    /// @notice Returns the keccak hash of the ABI-encoded StoredBlockInfo
    function _hashStoredBlockInfo(StoredBlockInfo memory _storedBlockInfo) internal pure returns (bytes32) {
        return keccak256(abi.encode(_storedBlockInfo));
    }
}

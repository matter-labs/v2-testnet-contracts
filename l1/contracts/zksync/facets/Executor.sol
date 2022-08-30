pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./Base.sol";
import "../Config.sol";
import "../interfaces/IExecutor.sol";
import "../libraries/PriorityQueue.sol";
import "../../common/libraries/UnsafeBytes.sol";

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

        // Check the timestamp of the new block
        {
            bool timestampNotTooSmall = block.timestamp - COMMIT_TIMESTAMP_NOT_OLDER <= blockTimestamp;
            bool timestampNotTooBig = blockTimestamp <= block.timestamp + COMMIT_TIMESTAMP_APPROXIMATION_DELTA;
            require(timestampNotTooSmall && timestampNotTooBig, "h"); // New block timestamp is not valid
        }

        // TODO: Restore after block commitment will be integrated
        // require(_previousBlock.blockHash == previousBlockHash, "l");

        // Create block commitment for the proof verification
        bytes32 commitment = _createBlockCommitment(_previousBlock, _newBlock);

        return
            StoredBlockInfo(
                _newBlock.blockNumber,
                _newBlock.numberOfLayer1Txs,
                priorityOperationsHash,
                _newBlock.l2LogsTreeRoot,
                _newBlock.newStateRoot,
                commitment
            );
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
        bytes memory l2Logs = _newBlock.l2Logs;
        bytes[] calldata L2Messages = _newBlock.l2ArbitraryLengthMessages;
        uint256 currentMessage;

        chainedPriorityTxsHash = EMPTY_STRING_KECCAK;

        require(l2Logs.length % L2_LOG_BYTES == 0, "k1");

        // linear traversal of the logs
        for (uint256 i = 0; i < l2Logs.length; ) {
            (address logSender, ) = UnsafeBytes.readAddress(l2Logs, i);

            // show preimage for hashed message stored in log
            if (logSender == L2_TO_L1_MESSENGER) {
                (bytes32 hashedMessage, ) = UnsafeBytes.readBytes32(l2Logs, i + 52);
                require(keccak256(L2Messages[currentMessage]) == hashedMessage, "k2");

                unchecked {
                    ++currentMessage;
                }
            } else if (logSender == L2_BOOTLOADER_ADDRESS) {
                (bytes32 canonicalTxHash, ) = UnsafeBytes.readBytes32(l2Logs, i + 20);
                chainedPriorityTxsHash = keccak256(bytes.concat(chainedPriorityTxsHash, canonicalTxHash));
            } else if (logSender == L2_SYSTEM_CONTEXT_ADDRESS) {
                (blockTimestamp, ) = UnsafeBytes.readUint256(l2Logs, i + 20);
                (previousBlockHash, ) = UnsafeBytes.readBytes32(l2Logs, i + 52);
            }

            // move the pointer to the next log
            unchecked {
                i += L2_LOG_BYTES;
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
        for (uint256 i = 0; i < blocksLength; ++i) {
            _lastCommittedBlockData = _commitOneBlock(_lastCommittedBlockData, _newBlocksData[i]);
            s.storedBlockHashes[_lastCommittedBlockData.blockNumber] = _hashStoredBlockInfo(_lastCommittedBlockData);
            emit BlockCommit(_lastCommittedBlockData.blockNumber);
        }

        s.totalBlocksCommitted = s.totalBlocksCommitted + blocksLength;
    }

    /// @dev Pops the priority operations from the priority queue and returns a rolling hash of operations
    function _collectOperationsFromPriorityQueue(uint16 _nPriorityOps) internal returns (bytes32 concatHash) {
        concatHash = EMPTY_STRING_KECCAK;

        for (uint256 i = 0; i < _nPriorityOps; ++i) {
            PriorityOperation memory priorityOp = s.priorityQueue.popFront();
            concatHash = keccak256(abi.encodePacked(concatHash, priorityOp.canonicalTxHash));
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
        for (uint256 i = 0; i < nBlocks; ++i) {
            _executeOneBlock(_blocksData[i], i);
            emit BlockExecution(_blocksData[i].blockNumber);
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

        emit BlocksRevert(s.totalBlocksExecuted, s.totalBlocksCommitted);
    }

    /// @notice Returns larger of two values
    function _maxU256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? b : a;
    }

    /// @dev Creates block commitment from its data
    function _createBlockCommitment(StoredBlockInfo memory _previousBlock, CommitBlockInfo calldata _newBlockData)
        internal
        view
        returns (bytes32)
    {
        bytes32 hash = sha256(abi.encodePacked(uint256(_newBlockData.blockNumber), _newBlockData.feeAccount));
        hash = sha256(abi.encodePacked(hash, _previousBlock.stateRoot));
        hash = sha256(abi.encodePacked(hash, _newBlockData.newStateRoot));
        hash = sha256(abi.encodePacked(hash, _newBlockData.l2LogsTreeRoot));
        // Number of operations requested from Layer 1 should NOT be included in the commitment
        // because the `priorityOperationsHash` is already commited to the priority operations
        hash = sha256(abi.encodePacked(hash, uint256(_newBlockData.numberOfLayer2Txs)));

        hash = _concatHash(hash, _newBlockData.l2Logs);
        hash = _concatHash(hash, _newBlockData.storageChanges);

        return hash;
    }

    function _concatHash(bytes32 _hash, bytes memory _bytes) internal view returns (bytes32 concatHash) {
        // The code below is equivalent to `concatHash = sha256(abi.encodePacked(_hash, _bytes))`
        // We use inline assembly instead of this concise and readable code in order to avoid copying of `_bytes`.

        // Specifically, we perform the following trick:
        // First, replace the first 32 bytes of `_bytes` (where normally its length is stored) with the value of `_hash`.
        // Then, we call `sha256` precompile passing the `_bytes` pointer and the length of the concatenated byte buffer.
        // Finally, we put the `_bytes.length` back to its original location (to the first word of `_bytes`).
        assembly {
            let hashResult := mload(0x40)
            let bytesLen := mload(_bytes)
            mstore(_bytes, _hash)
            // staticcall to the sha256 precompile at address 0x2
            let success := staticcall(gas(), 0x2, _bytes, add(bytesLen, 0x20), hashResult, 0x20)
            mstore(_bytes, bytesLen)

            // Use "invalid" to make gas estimation work
            switch success
            case 0 {
                invalid()
            }

            concatHash := mload(hashResult)
        }
    }

    /// @notice Returns the keccak hash of the ABI-encoded StoredBlockInfo
    function _hashStoredBlockInfo(StoredBlockInfo memory _storedBlockInfo) internal pure returns (bytes32) {
        return keccak256(abi.encode(_storedBlockInfo));
    }
}

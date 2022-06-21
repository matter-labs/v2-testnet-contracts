// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "./Base.sol";
import "../Config.sol";
import "../interfaces/IExecutor.sol";

import "../../common/libraries/UnsafeBytes.sol";
import "../libraries/Utils.sol";
import "../libraries/PriorityQueue.sol";
import "../libraries/PriorityModeLib.sol";
import "../libraries/CheckpointedPrefixSum.sol";

/// @title zkSync Executor contract capable of processing events emitted in the zkSync protocol.
/// @author Matter Labs
contract ExecutorFacet is Base, IExecutor {
    using PriorityQueue for PriorityQueue.Queue;
    using PriorityModeLib for PriorityModeLib.Epoch;
    using CheckpointedPrefixSum for CheckpointedPrefixSum.PrefixSum;

    /// @dev Process one block commit using previous block StoredBlockInfo
    /// @dev returns new block StoredBlockInfo
    /// @notice Does not change storage
    function _commitOneBlock(
        StoredBlockInfo memory _previousBlock,
        CommitBlockInfo calldata _newBlock,
        bool _onlyPriorityOperations
    ) internal view returns (StoredBlockInfo memory storedNewBlock) {
        require(_newBlock.blockNumber == _previousBlock.blockNumber + 1, "f"); // only commit next block

        // Check timestamp of the new block
        {
            require(_newBlock.timestamp >= _previousBlock.timestamp, "g"); // Block should be after previous block
            bool timestampNotTooSmall = block.timestamp - COMMIT_TIMESTAMP_NOT_OLDER <= _newBlock.timestamp;
            bool timestampNotTooBig = _newBlock.timestamp <= block.timestamp + COMMIT_TIMESTAMP_APPROXIMATION_DELTA;
            require(timestampNotTooSmall && timestampNotTooBig, "h"); // New block timestamp is not valid
        }

        // Check permission to commit block
        require(!_onlyPriorityOperations || _newBlock.numberOfLayer2Txs == 0, "t"); // Block cannot contain layer 2 txs in case of priority mode

        // Check that block contain all meta information for L2 logs.
        // And get chain hash of priority transaction hashes.
        bytes32 priorityOperationsHash = _processL2Logs(_newBlock);

        // Create block commitment for the proof verification
        bytes32 commitment = _createBlockCommitment(_previousBlock, _newBlock);

        return
            StoredBlockInfo(
                _newBlock.blockNumber,
                _newBlock.numberOfLayer1Txs,
                _newBlock.priorityOperationsComplexity,
                priorityOperationsHash,
                _newBlock.l2LogsTreeRoot,
                _newBlock.timestamp,
                _newBlock.newStateRoot,
                commitment
            );
    }

    /// @dev Check that L2 logs are proper and block contain all meta information for them
    function _processL2Logs(CommitBlockInfo calldata _newBlock) internal pure returns (bytes32) {
        bytes memory l2Logs = _newBlock.l2Logs;
        bytes[] calldata L2Messages = _newBlock.l2ArbitraryLengthMessages;
        uint256 currentMessage;

        bytes32 concatedPriorityTxsHash = EMPTY_STRING_KECCAK;

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
                concatedPriorityTxsHash = keccak256(bytes.concat(concatedPriorityTxsHash, canonicalTxHash));
            }

            // move pointer to the next log
            unchecked {
                i += L2_LOG_BYTES;
            }
        }

        return concatedPriorityTxsHash;
    }

    /// @notice Commit block
    /// @notice 1. Checks timestamp.
    /// @notice 2. Process L2 logs.
    /// @notice 3. Store block commitments.
    function commitBlocks(StoredBlockInfo memory _lastCommittedBlockData, CommitBlockInfo[] calldata _newBlocksData)
        external
        override
        nonReentrant
    {
        bool priorityModeEnabled = s.priorityModeState.priorityModeEnabled;
        if (priorityModeEnabled) {
            PriorityModeLib.updateEpoch(s);

            bool canProcessBlocks = s.priorityModeState.epoch.isProcessing() &&
                s.currentMaxAuctionBid.creator == address(msg.sender);
            require(canProcessBlocks, "y"); // During the priority mode, blocks can be committed only by the winner of the auction in the processing sub-epoch
        } else {
            _requireActiveValidator(msg.sender);
        }

        // Check that we commit blocks after last committed block
        require(s.storedBlockHashes[s.totalBlocksCommitted] == _hashStoredBlockInfo(_lastCommittedBlockData), "i"); // incorrect previous block data

        for (uint32 i = 0; i < _newBlocksData.length; ++i) {
            _lastCommittedBlockData = _commitOneBlock(_lastCommittedBlockData, _newBlocksData[i], priorityModeEnabled);
            s.storedBlockHashes[_lastCommittedBlockData.blockNumber] = _hashStoredBlockInfo(_lastCommittedBlockData);
            emit BlockCommit(_lastCommittedBlockData.blockNumber);
        }

        s.totalBlocksCommitted = s.totalBlocksCommitted + uint32(_newBlocksData.length);
    }

    /// @dev Pops the priority operations from the priority queue and returns a rolling hash of operations
    function _collectOperationsFromPriorityQueue(OpTree _opTree, uint16 _nPriorityOps) internal returns (bytes32) {
        bytes32 concatHash = EMPTY_STRING_KECCAK;

        if (_opTree == OpTree.Full) {
            // Take operations from the both heaps with layer 2 tip priority (expensive first)
            (_nPriorityOps, concatHash) = _collectMostExpensiveHeapOps(_nPriorityOps, concatHash);

            // If we still need to take operations, then take operations from common deque
            uint256 nOpsFromCommonDeque = Utils.minU256(uint256(_nPriorityOps), s.priorityQueue[_opTree].dequeSize());
            for (uint256 i = 0; i < nOpsFromCommonDeque; ++i) {
                concatHash = _collectOneOperationFromDeque(OpTree.Full, concatHash);
            }

            // If we still need to take operations, then take operations from rollup deque
            uint256 nOpsFromRollupDeque = _nPriorityOps - nOpsFromCommonDeque;

            // NOTE: Don't need to check that deque size is greater than `nOpsFromRollupDeque`,
            // because if we try to pull an operation out of an empty deque, the transaction will fail.
            for (uint256 i = 0; i < nOpsFromRollupDeque; ++i) {
                concatHash = _collectOneOperationFromDeque(OpTree.Rollup, concatHash);
            }
        } else {
            // Collect as many priority operations as possible from the rollup heap
            uint256 nPriorityOpsFromHeap = Utils.minU256(_nPriorityOps, s.priorityQueue[_opTree].heapSize());
            for (uint256 i = 0; i < nPriorityOpsFromHeap; ++i) {
                concatHash = _collectOneOperationFromHeap(_opTree, concatHash);
            }

            // If we still need to take operations, then take operations from rollup deque.
            uint256 nPriorityOpsFromDeque = _nPriorityOps - nPriorityOpsFromHeap;

            // NOTE: Don't need to check that deque size is greater than `nPriorityOpsFromDeque`,
            // because if we try to pull an operation out of an empty deque, the transaction will fail.
            for (uint256 i = 0; i < nPriorityOpsFromDeque; ++i) {
                concatHash = _collectOneOperationFromDeque(_opTree, concatHash);
            }
        }

        return concatHash;
    }

    /// @notice Collect priority operations from both heaps by priority layer 2 tip priority
    /// @return The number of transactions that have left to process and the collected concat hash
    function _collectMostExpensiveHeapOps(uint16 _nPriorityOps, bytes32 _concatedHash)
        internal
        returns (uint16, bytes32)
    {
        uint256 commonHeapSize = s.priorityQueue[OpTree.Full].heapSize();
        uint256 rollupHeapSize = s.priorityQueue[OpTree.Rollup].heapSize();

        // First, we will take the most expensive operation from the two heaps,
        // until collect as many operations as necessary or one of the heaps becomes empty.
        while (_nPriorityOps > 0 && commonHeapSize > 0 && rollupHeapSize > 0) {
            // Colleсt priority operation with the largest l2 tip
            OpTree maxTipOpTree = _maxTipHeapOpTreeQueue();
            _concatedHash = _collectOneOperationFromHeap(maxTipOpTree, _concatedHash);

            if (maxTipOpTree == OpTree.Full) {
                commonHeapSize -= 1;
            } else {
                rollupHeapSize -= 1;
            }

            _nPriorityOps -= 1;
        }

        // If there are still priority operations in one of the heaps and we still
        // need to take priority operations, then we will take them from this heap
        if (_nPriorityOps > 0 && commonHeapSize > 0) {
            uint256 nPriorityOpsFromHeap = Utils.minU256(uint256(_nPriorityOps), commonHeapSize);
            for (uint256 i = 0; i < nPriorityOpsFromHeap; ++i) {
                _concatedHash = _collectOneOperationFromHeap(OpTree.Full, _concatedHash);
            }
            _nPriorityOps -= uint16(nPriorityOpsFromHeap);
        }

        if (_nPriorityOps > 0 && rollupHeapSize > 0) {
            uint256 nPriorityOpsFromHeap = Utils.minU256(uint256(_nPriorityOps), rollupHeapSize);
            for (uint256 i = 0; i < nPriorityOpsFromHeap; ++i) {
                _concatedHash = _collectOneOperationFromHeap(OpTree.Rollup, _concatedHash);
            }
            _nPriorityOps -= uint16(nPriorityOpsFromHeap);
        }

        return (_nPriorityOps, _concatedHash);
    }

    /// @notice Returns the type of the queue with the highest tip from heap
    /// NOTE: Expects both heaps to be non-empty
    function _maxTipHeapOpTreeQueue() internal view returns (OpTree) {
        uint64 rollupHeapFrontOpID = s.priorityQueue[OpTree.Rollup].frontHeapOperationID();
        PriorityOperation storage rollupOp = s.storedOperations.inner[rollupHeapFrontOpID];

        uint64 commonHeapFrontOpID = s.priorityQueue[OpTree.Full].frontHeapOperationID();
        PriorityOperation storage commonOp = s.storedOperations.inner[commonHeapFrontOpID];

        return commonOp.layer2Tip >= rollupOp.layer2Tip ? OpTree.Full : OpTree.Rollup;
    }

    /// @notice Pulls the priority operation from the heap
    /// @return collected concat hash including pulled priority operation
    function _collectOneOperationFromHeap(OpTree _opTree, bytes32 _concatedHash) internal returns (bytes32) {
        uint64 priorityOpID = s.priorityQueue[_opTree].popFromHeap(s.storedOperations);
        PriorityOperation memory priorityOp = s.storedOperations.inner[priorityOpID];

        // Since the operation is no longer on the heap, decrease the priority operation
        // expiration counter for the corresponding expiration block number.
        s.expiringOpsCounter.heap[priorityOp.expirationBlock] -= 1;

        return keccak256(abi.encodePacked(_concatedHash, priorityOp.canonicalTxHash));
    }

    /// @notice Pulls the priority operation from the deque and return operation
    /// @return collected concat hash including pulled priority operation
    function _collectOneOperationFromDeque(OpTree _opTree, bytes32 _concatedHash) internal returns (bytes32) {
        uint64 priorityOpID = s.priorityQueue[_opTree].popFrontFromDeque();
        PriorityOperation memory priorityOp = s.storedOperations.inner[priorityOpID];

        return keccak256(abi.encodePacked(_concatedHash, priorityOp.canonicalTxHash));
    }

    /// @dev Executes one block
    /// @dev 1. Processes all pending operations (Send Exits, Complete priority requests)
    /// @dev 2. Finalizes block on Ethereum
    /// @dev _executedBlockIdx is index in the array of the blocks that we want to execute together
    function _executeOneBlock(
        StoredBlockInfo memory _storedBlock,
        uint32 _executedBlockIdx,
        OpTree opTree
    ) internal {
        uint32 currentBlockNumber = _storedBlock.blockNumber;
        require(currentBlockNumber == s.totalBlocksExecuted + _executedBlockIdx + 1, "k"); // Execute blocks in order
        require(
            _hashStoredBlockInfo(_storedBlock) == s.storedBlockHashes[currentBlockNumber],
            "exe10" // executing block should be committed
        );

        uint16 nPriorityOps = _storedBlock.numberOfLayer1Txs;
        bytes32 priorityOperationsHash = _collectOperationsFromPriorityQueue(opTree, nPriorityOps);
        require(priorityOperationsHash == _storedBlock.priorityOperationsHash, "x"); // priority operations hash does not match to expected

        uint224 processedComplexity = _storedBlock.priorityOperationsComplexity;
        s.processedComplexityHistory.pushCheckpointWithCurrentBlockNumber(processedComplexity);

        // Save root hash of L2 -> L1 logs tree
        s.l2LogsRootHashes[currentBlockNumber] = _storedBlock.l2LogsTreeRoot;
    }

    /// @notice Execute blocks, completing priority operations and processing withdrawals.
    /// @notice 1. Processes all pending operations (Send Exits, Complete priority requests)
    /// @notice 2. Finalizes block on Ethereum
    function executeBlocks(StoredBlockInfo[] calldata _blocksData) external nonReentrant {
        OpTree opTree = OpTree.Full;

        if (s.priorityModeState.priorityModeEnabled) {
            PriorityModeLib.updateEpoch(s);

            bool canProcessBlocks = s.priorityModeState.epoch.isProcessing() &&
                s.currentMaxAuctionBid.creator == address(msg.sender);
            require(canProcessBlocks, "a"); // During the priority mode, blocks can be executed only by the winner of the auction in the processing sub-epoch

            if (s.priorityModeState.epoch == PriorityModeLib.Epoch.RollupProcessing) {
                opTree = OpTree.Rollup;
            }
        } else {
            _requireActiveValidator(msg.sender);
        }

        uint32 nBlocks = uint32(_blocksData.length);
        for (uint32 i = 0; i < nBlocks; ++i) {
            _executeOneBlock(_blocksData[i], i, opTree);
            emit BlockExecution(_blocksData[i].blockNumber);
        }

        s.totalBlocksExecuted = s.totalBlocksExecuted + nBlocks;
        require(s.totalBlocksExecuted <= s.totalBlocksVerified, "n"); // Can't execute blocks more then committed and proven currently.
    }

    /// @notice Blocks commitment verification.
    /// @notice Only verifies block commitments without any other processing
    function proveBlocks(StoredBlockInfo[] calldata _committedBlocks, ProofInput memory _proof) external nonReentrant {
        uint256 i;
        uint32 currentTotalBlocksVerified = s.totalBlocksVerified;

        // Ignoring the `_committedBlocks` which are already proved.
        bytes32 firstUnverifiedBlockHash = s.storedBlockHashes[currentTotalBlocksVerified + 1];
        while (_hashStoredBlockInfo(_committedBlocks[i]) != firstUnverifiedBlockHash) {
            unchecked {
                ++i;
            }
        }

        // Check that all other blocks are committed and have same commitment as `_proof`.
        while (i < _committedBlocks.length) {
            require(
                _hashStoredBlockInfo(_committedBlocks[i]) == s.storedBlockHashes[currentTotalBlocksVerified + 1],
                "o1"
            );

            require(_proof.commitments[i] & INPUT_MASK == uint256(_committedBlocks[i].commitment) & INPUT_MASK, "o"); // incorrect block commitment in proof

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
    function revertBlocks(uint32 _newLastBlock) external nonReentrant {
        if (s.priorityModeState.priorityModeEnabled) {
            PriorityModeLib.updateEpoch(s);
            bool canRevertBlocks = s.priorityModeState.epoch.isProcessing() &&
                s.currentMaxAuctionBid.creator == address(msg.sender);
            require(canRevertBlocks, "v"); // During the priority mode, blocks can be reverted only by the winner of the auction in the processing sub-epoch
        } else {
            _requireActiveValidator(msg.sender);
        }

        Utils.revertBlocks(s, _newLastBlock);
    }

    /// @notice Moves priority operations from the buffer to the main queue from which they can be performed
    /// @param _nOpsToMove Maximum number of operations to move
    /// @param _opTree Type of priority op processing queue, from which the operations will be moved first
    /// NOTE: Priority operations are moved first with the specified `_opTree` queue and then from the another queue
    function movePriorityOpsFromBufferToMainQueue(uint256 _nOpsToMove, OpTree _opTree) external nonReentrant {
        // #if TESTNET
        revert("t3"); // this functionality is disabled on testnet
        // #else
        if (s.priorityModeState.priorityModeEnabled) {
            PriorityModeLib.updateEpoch(s);
            require(s.priorityModeState.epoch == PriorityModeLib.Epoch.Delay, "A"); // in priority mode ops can be moved only in delay sub epoch
        } else {
            _requireActiveValidator(msg.sender);
        }

        // When an operation is added to the buffer heap, an expiration block is set for it as Ethereum block number before
        // which operation should be moved to the main heap. After the move, the deadline for its processing from the main heap
        // should be changed so that it can be processed `PRIORITY_EXPIRATION` blocks after the current block number.
        uint32 expirationBlock = uint32(block.number + PRIORITY_EXPIRATION);

        (uint256 gasUsedForMoving, uint64[] memory movedOperationIDs) = _movePriorityOps(
            _nOpsToMove,
            _opTree,
            expirationBlock
        );

        // In order for the executor to be able to prove that he has spent enough gas to move priority operations,
        // it is necessary to save the checkpoint with currect Ethereum block in the prefix sum array.
        s.movementOperationsGasUsage.pushCheckpointWithCurrentBlockNumber(uint224(gasUsedForMoving));

        emit MovePriorityOperationsFromBufferToHeap(expirationBlock, movedOperationIDs, _opTree);
        // #endif
    }

    /// @notice Moves priority operations from the buffer to the main queue
    /// @param _nOpsToMove Maximum number of priority operations that can be moved
    /// @param _opTree Type of priority op processing queue, from which the operations will be moved first
    /// @param _newExpirationBlock Block number up to which the operations should be processed from the main heap
    /// @return Gas spent on movement and an array of IDs for moved priority operations
    function _movePriorityOps(
        uint256 _nOpsToMove,
        OpTree _opTree,
        uint32 _newExpirationBlock
    ) internal returns (uint256, uint64[] memory) {
        uint256 gasLeftBefore = gasleft();

        OpTree oppositeOpTree = _oppositeOpTree(_opTree);

        uint256 firstBufferSize = s.priorityQueue[_opTree].heapBufferSize();
        uint256 secondBufferSize = s.priorityQueue[oppositeOpTree].heapBufferSize();

        uint256 nOpsToMoveFromFirstBuffer = Utils.minU256(_nOpsToMove, firstBufferSize);
        uint256 nOpsToMoveFromSecondBuffer = Utils.minU256(_nOpsToMove - nOpsToMoveFromFirstBuffer, secondBufferSize);

        uint256 totalOpsToMove = nOpsToMoveFromFirstBuffer + nOpsToMoveFromSecondBuffer;
        require(totalOpsToMove > 0, "r"); // The number of operations to move must not be zero

        uint64[] memory movedOperationIDs = new uint64[](totalOpsToMove);

        for (uint256 i = 0; i < nOpsToMoveFromFirstBuffer; ++i) {
            uint64 operationID = _moveOnePriorityOpFromBufferToMainHeap(_opTree, _newExpirationBlock);
            movedOperationIDs[i] = operationID;
        }

        for (uint256 i = 0; i < nOpsToMoveFromSecondBuffer; ++i) {
            uint64 operationID = _moveOnePriorityOpFromBufferToMainHeap(oppositeOpTree, _newExpirationBlock);
            movedOperationIDs[nOpsToMoveFromFirstBuffer + i] = operationID;
        }

        uint256 gasLeftAfter = gasleft();

        return (gasLeftBefore - gasLeftAfter, movedOperationIDs);
    }

    /// @notice Moves exactly one priority operation from the heap buffer to the main heap.
    /// @param _opTree Type of priority op processing queue, from which the operation will be moved
    /// @param _newExpirationBlock Block number up to which the operation should be processed from the main heap
    /// NOTE: Changes the expiration block number for the operation being moved and also updates information in additional counters for heaps.
    /// @return ID of the priority operation that was moved
    function _moveOnePriorityOpFromBufferToMainHeap(OpTree _opTree, uint32 _newExpirationBlock)
        internal
        returns (uint64)
    {
        uint64 operationID = s.priorityQueue[_opTree].popFromBufferHeap(s.storedOperations);

        PriorityOperation storage operation = s.storedOperations.inner[operationID];

        // The operation is no longer in the buffer, so decrease the operation counter with the its expiration block
        // and increase the counter of operations with its new expiration block since the operation will be in the main heap.
        s.expiringOpsCounter.bufferHeap[operation.expirationBlock] -= 1;
        s.expiringOpsCounter.heap[_newExpirationBlock] += 1;

        // Сhange the priority operation expiration block to a new one.
        operation.expirationBlock = _newExpirationBlock;

        s.priorityQueue[_opTree].pushToHeap(s.storedOperations, operationID);

        return operationID;
    }

    /// @notice Returns opposite of tree for given op tree type
    function _oppositeOpTree(OpTree _opTree) internal pure returns (OpTree oppositeOpTree) {
        oppositeOpTree = _opTree == OpTree.Full ? OpTree.Rollup : OpTree.Full;
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
        hash = sha256(abi.encodePacked(hash, _newBlockData.timestamp));
        hash = sha256(abi.encodePacked(hash, uint256(_newBlockData.priorityOperationsComplexity)));
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

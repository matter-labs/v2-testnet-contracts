pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED



import "../../Operations.sol";
import "../../libraries/PriorityQueue.sol";
import "../../libraries/CheckpointedPrefixSum.sol";

import "../../facets/Base.sol";

contract DummyPriorityQueue is Base {
    using CheckpointedPrefixSum for CheckpointedPrefixSum.PrefixSum;
    using PriorityQueue for PriorityQueue.Queue;

    /// @dev Set of parameters that are needed to test the processing of priority operations
    struct DummyPriorityOperation {
        uint64 id;
        uint64 expirationBlock;
        uint192 layer2Tip;
    }

    /// @dev Adds a new checkpoint for processed compexity statistics
    function pushDummyComplexityCheckpoint(uint224 _value) external {
        s.processedComplexityHistory.pushCheckpointWithCurrentBlockNumber(_value);
    }

    /// @dev Adds a new checkpoint for gas usage on movement statistics
    function pushDummyMovementGasUsageCheckpoint(uint224 _value) external {
        s.movementOperationsGasUsage.pushCheckpointWithCurrentBlockNumber(_value);
    }

    function pushDummyOpToDeque(OpTree _opTree, DummyPriorityOperation memory _dummyPriorityOp) external {
        _saveDummyOperation(_dummyPriorityOp);

        s.priorityQueue[_opTree].pushBackToDeque(_dummyPriorityOp.id);
    }

    function pushDummyOpsToMainHeap(OpTree _opTree, DummyPriorityOperation[] memory _dummyPriorityOps) external {
        for (uint256 i = 0; i < _dummyPriorityOps.length; ++i) {
            _pushOneDummyOpsToMainHeap(_opTree, _dummyPriorityOps[i]);
        }
    }

    function pushDummyOpsToBufferHeap(OpTree _opTree, DummyPriorityOperation[] memory _dummyPriorityOps) external {
        for (uint256 i = 0; i < _dummyPriorityOps.length; ++i) {
            _pushOneDummyOpsToBufferHeap(_opTree, _dummyPriorityOps[i]);
        }
    }

    /// @dev returns all priority ops in the same order in which they are stored on the heap
    function getHeapWithDummyOps(OpTree _opTree) external view returns (DummyPriorityOperation[] memory dummyOps) {
        uint64[] memory operationIDs = s.priorityQueue[_opTree].heap.data;

        dummyOps = new DummyPriorityOperation[](operationIDs.length);
        for (uint256 i = 0; i < operationIDs.length; ++i) {
            uint64 id = operationIDs[i];

            PriorityOperation memory priorityOp = s.storedOperations.inner[id];

            dummyOps[i] = DummyPriorityOperation(id, priorityOp.expirationBlock, priorityOp.layer2Tip);
        }
    }

    /// @dev returns the number of elements in the buffer heap
    function getHeapBufferSize(OpTree _opTree) external view returns (uint256) {
        return s.priorityQueue[_opTree].heapBufferSize();
    }

    /// @dev removes all elements from both deques
    function clearDeques() external {
        _clearDeque(OpTree.Full);
        _clearDeque(OpTree.Rollup);
    }

    function _pushOneDummyOpsToMainHeap(OpTree _opTree, DummyPriorityOperation memory _dummyPriorityOp) internal {
        _saveDummyOperation(_dummyPriorityOp);

        // Increase the counter of expiration blocks operations
        s.expiringOpsCounter.heap[_dummyPriorityOp.expirationBlock] += 1;

        s.priorityQueue[_opTree].pushToHeap(s.storedOperations, _dummyPriorityOp.id);
    }

    function _pushOneDummyOpsToBufferHeap(OpTree _opTree, DummyPriorityOperation memory _dummyPriorityOp) internal {
        _saveDummyOperation(_dummyPriorityOp);

        // Increase the counter of expiration blocks operations
        s.expiringOpsCounter.bufferHeap[_dummyPriorityOp.expirationBlock] += 1;

        s.priorityQueue[_opTree].pushToBufferHeap(s.storedOperations, _dummyPriorityOp.id);
    }

    /// @dev removes all elements from the deque
    function _clearDeque(OpTree _opTree) internal {
        uint256 dequeSize = s.priorityQueue[_opTree].dequeSize();

        for (uint256 i = 0; i < dequeSize; ++i) {
            s.priorityQueue[_opTree].popFrontFromDeque();
        }
    }

    /// @dev stores information about the operation in storage but does not insert it into any structure
    function _saveDummyOperation(DummyPriorityOperation memory _dummyPriorityOp) internal {
        uint64 id = _dummyPriorityOp.id;
        uint64 expirationBlock = _dummyPriorityOp.expirationBlock;
        uint192 layer2Tip = _dummyPriorityOp.layer2Tip;

        // Transform dummy operation to normal operation
        PriorityOperation memory priorityOp = PriorityOperation({
            canonicalTxHash: bytes32(0),
            expirationBlock: expirationBlock,
            layer2Tip: layer2Tip
        });

        s.storedOperations.inner[id] = priorityOp;
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED



import "../../Operations.sol";
import "../../libraries/PriorityQueue.sol";

contract PriorityQueueTest {
    using PriorityQueue for PriorityQueue.Queue;

    uint64 internal totalPriorityRequests;
    StoredOperations internal storedOperations;
    PriorityQueue.Queue internal priorityQueue;

    /// @notice Adds a priority operation to the queue
    /// @param _queueType type of queue to which the operation will be added (Deque/Heap)
    /// @param _layer2Tip Additional tip for the operator to stimulate the processing operation (key on the max heap)
    function push(QueueType _queueType, uint192 _layer2Tip) external {
        // Create priority operation with zero data and given layer 2 tip
        PriorityOperation memory priorityOp = PriorityOperation({
            canonicalTxHash: bytes32(0),
            expirationBlock: uint64(0),
            layer2Tip: _layer2Tip
        });
        storedOperations.inner[totalPriorityRequests] = priorityOp;

        if (_queueType == QueueType.Deque) {
            priorityQueue.pushBackToDeque(totalPriorityRequests);
        } else if (_queueType == QueueType.HeapBuffer) {
            priorityQueue.pushToBufferHeap(storedOperations, totalPriorityRequests);
        } else {
            priorityQueue.pushToHeap(storedOperations, totalPriorityRequests);
        }

        ++totalPriorityRequests;
    }

    /// @notice pops an operation from a given queue
    function pop(QueueType _queueType) external {
        if (_queueType == QueueType.Deque) {
            priorityQueue.popFrontFromDeque();
        } else if (_queueType == QueueType.HeapBuffer) {
            priorityQueue.popFromBufferHeap(storedOperations);
        } else {
            priorityQueue.popFromHeap(storedOperations);
        }
    }

    /// @notice return layer 2 tip for the top operation in queue with given type
    function top(QueueType _queueType) external view returns (uint192 layer2Tip) {
        uint64 priorityOpID;
        if (_queueType == QueueType.Deque) {
            priorityOpID = priorityQueue.frontDequeOperationID();
        } else if (_queueType == QueueType.HeapBuffer) {
            priorityOpID = priorityQueue.frontHeapBufferOperationID();
        } else {
            priorityOpID = priorityQueue.frontHeapOperationID();
        }

        layer2Tip = storedOperations.inner[priorityOpID].layer2Tip;
    }
}

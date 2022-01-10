pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED



import "../../libraries/Operations.sol";
import "../../libraries/PriorityQueue.sol";

contract PriorityQueueTest {
    using PriorityQueue for PriorityQueue.Queue;

    uint64 internal totalPriorityRequests;
    Operations.StoredOperations internal storedOperations;
    PriorityQueue.Queue internal priorityQueue;

    /// @notice Adds a priority operation to the queue
    /// @param _queueType type of queue to which the operation will be added (Deque/Heap)
    /// @param _layer2Tip Additional tip for the operator to stimulate the processing operation (key on the max heap)
    function push(Operations.QueueType _queueType, uint96 _layer2Tip) external {
        // Create priority operation with zero data and given layer 2 tip
        Operations.PriorityOperation memory priorityOp = Operations.PriorityOperation({
            hashedCircuitOpData: bytes16(uint128(0)),
            expirationBlock: uint32(0),
            layer2Tip: _layer2Tip
        });
        storedOperations.inner[totalPriorityRequests] = priorityOp;

        if (_queueType == Operations.QueueType.Deque) {
            priorityQueue.pushBackToDeque(totalPriorityRequests);
        } else if (_queueType == Operations.QueueType.HeapBuffer) {
            priorityQueue.pushToBufferHeap(storedOperations, totalPriorityRequests);
        } else {
            priorityQueue.pushToHeap(storedOperations, totalPriorityRequests);
        }

        ++totalPriorityRequests;
    }

    /// @notice pops an operation from a given queue
    function pop(Operations.QueueType _queueType) external {
        if (_queueType == Operations.QueueType.Deque) {
            priorityQueue.popFrontFromDeque();
        } else if (_queueType == Operations.QueueType.HeapBuffer) {
            priorityQueue.popFromBufferHeap(storedOperations);
        } else {
            priorityQueue.popFromHeap(storedOperations);
        }
    }

    /// @notice return layer 2 tip for the top operation in queue with given type
    function top(Operations.QueueType _queueType) external view returns (uint96 layer2Tip) {
        uint64 priorityOpID;
        if (_queueType == Operations.QueueType.Deque) {
            priorityOpID = priorityQueue.frontDequeOperationID();
        } else if (_queueType == Operations.QueueType.HeapBuffer) {
            priorityOpID = priorityQueue.frontHeapBufferOperationID();
        } else {
            priorityOpID = priorityQueue.frontHeapOperationID();
        }

        layer2Tip = storedOperations.inner[priorityOpID].layer2Tip;
    }
}

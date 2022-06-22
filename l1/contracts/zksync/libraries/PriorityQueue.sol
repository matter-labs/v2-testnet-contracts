pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../Operations.sol";

/// @title queue with several data structure for storing priority operations
/// @author Matter Labs
library PriorityQueue {
    using HeapLibrary for HeapLibrary.Heap;
    using DequeLibrary for DequeLibrary.Deque;

    /// @param heapBuffer structure to which priority operations with high priority are added before moving to the heap
    /// @param heap structure to which priority operations are stored ordered by `L2Tip`
    /// @param deque structure to which operations added cheaper than in the heap, but have smaller priority
    struct Queue {
        HeapLibrary.Heap heapBuffer;
        HeapLibrary.Heap heap;
        DequeLibrary.Deque deque;
    }

    function pushToBufferHeap(
        Queue storage _queue,
        StoredOperations storage _storedOperations,
        uint64 _operationID
    ) internal {
        _queue.heapBuffer.push(_storedOperations, _operationID);
    }

    function pushBackToDeque(Queue storage _queue, uint64 _operationID) internal {
        _queue.deque.pushBack(_operationID);
    }

    function pushToHeap(
        Queue storage _queue,
        StoredOperations storage _storedOperations,
        uint64 _operationID
    ) internal {
        _queue.heap.push(_storedOperations, _operationID);
    }

    function popFromHeap(Queue storage _queue, StoredOperations storage _storedOperations) internal returns (uint64) {
        return _queue.heap.pop(_storedOperations);
    }

    function popFromBufferHeap(Queue storage _queue, StoredOperations storage _storedOperations)
        internal
        returns (uint64)
    {
        return _queue.heapBuffer.pop(_storedOperations);
    }

    function popFrontFromDeque(Queue storage _queue) internal returns (uint64) {
        return _queue.deque.popFront();
    }

    function frontDequeOperationID(Queue storage _queue) internal view returns (uint64) {
        return _queue.deque.front();
    }

    function frontHeapBufferOperationID(Queue storage _queue) internal view returns (uint64) {
        return _queue.heapBuffer.top();
    }

    function frontHeapOperationID(Queue storage _queue) internal view returns (uint64) {
        return _queue.heap.top();
    }

    function heapBufferSize(Queue storage _queue) internal view returns (uint256) {
        return _queue.heapBuffer.getSize();
    }

    function heapSize(Queue storage _queue) internal view returns (uint256) {
        return _queue.heap.getSize();
    }

    function dequeSize(Queue storage _queue) internal view returns (uint256) {
        return _queue.deque.getSize();
    }

    function getTotalHeapsHeight(Queue storage _queue) internal view returns (uint64) {
        return _queue.heap.getHeight() + _queue.heapBuffer.getHeight();
    }
}

/// @title HeapLibrary implementation of heap data structure
/// @author Matter Labs
library HeapLibrary {
    struct Heap {
        uint64[] data;
        uint64 height;
    }

    function top(Heap storage _heap) internal view returns (uint64 _operationID) {
        require(_heap.data.length > 0, "e"); // heap is empty

        return _heap.data[0];
    }

    function push(
        Heap storage _heap,
        StoredOperations storage _storedOperations,
        uint64 _operationID
    ) internal {
        _heap.data.push(_operationID);
        uint256 childIndex = _heap.data.length - 1;

        while (
            childIndex > 0 &&
            _storedOperations.inner[_heap.data[childIndex]].layer2Tip >
            _storedOperations.inner[_heap.data[(childIndex - 1) / 2]].layer2Tip
        ) {
            uint256 parrentIndex = (childIndex - 1) / 2;
            _heap.data[childIndex] = _heap.data[parrentIndex];
            _heap.data[parrentIndex] = _operationID;

            childIndex = parrentIndex;
        }

        // Check that number of elements in the heap after addition is a power of two
        // if so then increase the heap height by 1
        uint256 len = _heap.data.length;
        if ((len & (len - 1)) == 0) {
            _heap.height += 1;
        }
    }

    function pop(Heap storage _heap, StoredOperations storage _storedOperations)
        internal
        returns (uint64 _operationID)
    {
        require(_heap.data.length > 0, "w"); // heap is empty

        uint64 result = _heap.data[0];

        _heap.data[0] = _heap.data[_heap.data.length - 1];
        _heap.data.pop();

        uint256 parrentIndex = 0;
        while (2 * parrentIndex + 1 < _heap.data.length) {
            uint256 childIndex = 2 * parrentIndex + 1;
            if (
                childIndex + 1 < _heap.data.length &&
                _storedOperations.inner[_heap.data[childIndex]].layer2Tip <
                _storedOperations.inner[_heap.data[childIndex + 1]].layer2Tip
            ) {
                childIndex += 1;
            }

            if (
                _storedOperations.inner[_heap.data[childIndex]].layer2Tip >
                _storedOperations.inner[_heap.data[parrentIndex]].layer2Tip
            ) {
                uint64 tmpValue = _heap.data[parrentIndex];
                _heap.data[parrentIndex] = _heap.data[childIndex];
                _heap.data[childIndex] = tmpValue;

                parrentIndex = childIndex;
            } else {
                break;
            }
        }

        // Check that number of elements in the heap before removing was a power of two
        // if so then decrease the heap height by 1
        uint256 len = _heap.data.length;
        if ((len & (len + 1)) == 0) {
            _heap.height -= 1;
        }

        return result;
    }

    function getSize(Heap storage _heap) internal view returns (uint256) {
        return _heap.data.length;
    }

    function getHeight(Heap storage _heap) internal view returns (uint64) {
        return _heap.height;
    }
}

/// @title DequeLibrary implementation of deque data structure
/// @author Matter Labs
library DequeLibrary {
    struct Deque {
        mapping(uint128 => uint64) data;
        uint128 head;
        uint128 tail;
    }

    function getSize(Deque storage _deque) internal view returns (uint256) {
        return uint256(_deque.head - _deque.tail);
    }

    function isEmpty(Deque storage _deque) internal view returns (bool) {
        return _deque.head == _deque.tail;
    }

    function pushBack(Deque storage _deque, uint64 _operationID) internal {
        _deque.data[_deque.head] = _operationID;
        _deque.head += 1;
    }

    function front(Deque storage _deque) internal view returns (uint64) {
        require(!isEmpty(_deque), "D"); // deque is empty

        return _deque.data[_deque.tail];
    }

    function popFront(Deque storage _deque) internal returns (uint64 frontOperationID) {
        require(!isEmpty(_deque), "s"); // deque is empty

        frontOperationID = _deque.data[_deque.tail];
        delete _deque.data[_deque.tail];
        _deque.tail += 1;
    }
}

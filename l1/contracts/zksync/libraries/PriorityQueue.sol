pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



/// @notice Priority Operation container
/// @param canonicalTxHash Hashed priority operation data that is needed to process the operation
/// @param expirationBlock Expiration block number (ETH block) for this request (must be satisfied before)
/// @param layer2Tip Additional payment to the operator as an incentive to perform the operation
struct PriorityOperation {
    bytes32 canonicalTxHash;
    uint64 expirationBlock;
    uint192 layer2Tip;
}

/// @author Matter Labs
library PriorityQueue {
    using PriorityQueue for Queue;

    struct Queue {
        mapping(uint256 => PriorityOperation) data;
        uint256 head;
        uint256 tail;
    }

    function getLastProcessedPriorityTx(Queue storage _queue) internal view returns (uint256) {
        return _queue.tail;
    }

    function getTotalPriorityTxs(Queue storage _queue) internal view returns (uint256) {
        return _queue.head;
    }

    function getSize(Queue storage _queue) internal view returns (uint256) {
        return uint256(_queue.head - _queue.tail);
    }

    function isEmpty(Queue storage _queue) internal view returns (bool) {
        return _queue.head == _queue.tail;
    }

    function pushBack(Queue storage _queue, PriorityOperation memory _operation) internal {
        // Save value into the stack to avoid double reading from the storage
        uint256 head = _queue.head;

        _queue.data[head] = _operation;
        _queue.head = head + 1;
    }

    function front(Queue storage _queue) internal view returns (PriorityOperation memory) {
        require(!_queue.isEmpty(), "D"); // priority queue is empty

        return _queue.data[_queue.tail];
    }

    function popFront(Queue storage _queue) internal returns (PriorityOperation memory operation) {
        require(!_queue.isEmpty(), "s"); // priority queue is empty

        // Save value into the stack to avoid double reading from the storage
        uint256 tail = _queue.tail;

        operation = _queue.data[tail];
        delete _queue.data[tail];
        _queue.tail = tail + 1;
    }
}

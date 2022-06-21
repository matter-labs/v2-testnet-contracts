// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

/// @notice Priority Operation container
/// @param canonicalTxHash Hashed priority operation data that is needed to process the operation
/// @param expirationBlock Expiration block number (ETH block) for this request (must be satisfied before)
/// @param layer2Tip Additional payment to the operator as an incentive to perform the operation
struct PriorityOperation {
    bytes32 canonicalTxHash;
    uint64 expirationBlock;
    uint192 layer2Tip;
}

/// @notice A structure that stores all priority operations by ID
/// used for easy acceptance as an argument in functions
struct StoredOperations {
    mapping(uint64 => PriorityOperation) inner;
}

/// @notice Indicator that the operation can interact with Rollup and Porter trees, or only with Rollup
enum OpTree {
    Full,
    Rollup
}

/// @notice Priority operations queue type
enum QueueType {
    Deque,
    HeapBuffer,
    Heap
}

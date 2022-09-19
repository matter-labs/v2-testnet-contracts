pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



bytes32 constant EMPTY_STRING_KECCAK = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

/// @dev Bytes in raw L2 log
uint256 constant L2_LOG_BYTES = 20+32+32; // Address + bytes32 + bytes32

/// @dev address of the special smart contract that can send arbitrary length message as an L2 log
address constant L2_TO_L1_MESSENGER = address(0x8008);

// TODO: change constant to the real root hash of empty Merkle tree (SMA-184)
bytes32 constant DEFAULT_L2_LOGS_TREE_ROOT_HASH = bytes32(0);

address constant L2_BOOTLOADER_ADDRESS = address(0x8001);

address constant L2_SYSTEM_CONTEXT_ADDRESS = address(0x800b);

/// @dev  Denotes the first byte of the zkSync's transaction that came from L1.
uint256 constant PRIORITY_OPERATION_L2_TX_TYPE = 255;

/// @dev Expected average period of block creation
uint256 constant BLOCK_PERIOD = 13 seconds;

/// @dev Expiration delta for priority request to be satisfied (in seconds)
/// @dev otherwise incorrect block with priority op could not be reverted.
uint256 constant PRIORITY_EXPIRATION_PERIOD = 3 days;

/// @dev Expiration delta for priority request to be satisfied (in ETH blocks)
uint256 constant PRIORITY_EXPIRATION = PRIORITY_EXPIRATION_PERIOD/BLOCK_PERIOD;

/// @dev Notice period before activation preparation status of upgrade mode (in seconds)
/// @dev NOTE: we must reserve for users enough time to send full exit operation, wait maximum time for processing this operation and withdraw funds from it.
uint256 constant UPGRADE_NOTICE_PERIOD = 0;

/// @dev Timestamp - seconds since unix epoch
uint256 constant COMMIT_TIMESTAMP_NOT_OLDER = 365 days;

/// @dev Maximum available error between real commit block timestamp and analog used in the verifier (in seconds)
/// @dev Must be used cause miner's `block.timestamp` value can differ on some small value (as we know - 15 seconds)
uint256 constant COMMIT_TIMESTAMP_APPROXIMATION_DELTA = 365 days;

/// @dev Bit mask to apply for verifier public input before verifying.
uint256 constant INPUT_MASK = 14474011154664524427946373126085988481658748083205070504932198000989141204991;

/// @dev Number of security council members that should approve an emergency upgrade
uint256 constant SECURITY_COUNCIL_APPROVALS_FOR_EMERGENCY_UPGRADE = 1;

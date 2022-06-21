// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

bytes32 constant EMPTY_STRING_KECCAK = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

/// @dev Bytes in raw L2 log
uint256 constant L2_LOG_BYTES = $(20 + 32 + 32); // Address + bytes32 + bytes32

/// @dev address of the special smart contract that can send arbitrary length message as a L2 log
address constant L2_TO_L1_MESSENGER = address(0x8008);

// TODO: change constant to the real root hash of empty Merkle tree (SMA-184)
bytes32 constant DEFAULT_L2_LOGS_TREE_ROOT_HASH = bytes32(0);

address constant L2_BOOTLOADER_ADDRESS = address(0x8001);

/// @dev a value that is added to the address of the contract account from which the priority operation is requested.
uint160 constant ADDRESS_ALIAS_OFFSET = uint160(0x1111000000000000000000000000000000001111);

/// @dev ERC20 tokens and ETH withdrawals gas limit, used only for complete withdrawals
uint256 constant WITHDRAWAL_GAS_LIMIT = 100000;

/// @dev  Denotes the first byte of the zkSync's transaction that came from L1.
uint256 constant PRIORITY_OPERATION_L2_TX_TYPE = 255;

/// @dev Expected average period of block creation
uint256 constant BLOCK_PERIOD = 13 seconds;

/// @dev Expiration delta for priority request to be satisfied (in seconds)
/// @dev otherwise incorrect block with priority op could not be reverted.
uint256 constant PRIORITY_EXPIRATION_PERIOD = 3 days;

/// @dev Expiration delta for priority request to be satisfied (in ETH blocks)
uint256 constant PRIORITY_EXPIRATION = 0;
//$(defined(PRIORITY_EXPIRATION) ? PRIORITY_EXPIRATION : PRIORITY_EXPIRATION_PERIOD / BLOCK_PERIOD);

/// @dev Notice period before activation preparation status of upgrade mode (in seconds)
/// @dev NOTE: we must reserve for users enough time to send full exit operation, wait maximum time for processing this operation and withdraw funds from it.
uint256 constant UPGRADE_NOTICE_PERIOD = $$(defined(UPGRADE_NOTICE_PERIOD) ? UPGRADE_NOTICE_PERIOD : "14 days");

/// @dev Timestamp - seconds since unix epoch
uint256 constant COMMIT_TIMESTAMP_NOT_OLDER = $$(
    defined(COMMIT_TIMESTAMP_NOT_OLDER) ? COMMIT_TIMESTAMP_NOT_OLDER : "365 days"
);

/// @dev Maximum available error between real commit block timestamp and analog used in the verifier (in seconds)
/// @dev Must be used cause miner's `block.timestamp` value can differ on some small value (as we know - 15 seconds)
uint256 constant COMMIT_TIMESTAMP_APPROXIMATION_DELTA = $$(
    defined(COMMIT_TIMESTAMP_APPROXIMATION_DELTA) ? COMMIT_TIMESTAMP_APPROXIMATION_DELTA : "365 days"
);

/// @dev Bit mask to apply for verifier public input before verifying.
uint256 constant INPUT_MASK = $$(~uint256(0) >> 3);

/// @dev The time it takes for the operator to add a priority operation from the buffer to the heap.
uint256 constant PRIORITY_BUFFER_EXPIRATION = 0; //3 days / BLOCK_PERIOD;

// TODO: reestimate this value!
uint256 constant EXECUTE_CONTRACT_PRIORITY_OPERATION_GAS_COST = 1;

uint192 constant PRIORITY_TRANSACTION_FEE_BURN_PERCENTAGE = 2;
uint192 constant PRIORITY_TRANSACTION_FEE_BURN_COEF = 100 / PRIORITY_TRANSACTION_FEE_BURN_PERCENTAGE;

uint256 constant EXPECTED_PROCESSED_COMPLEXITY = $$(EXPECTED_PROCESSED_COMPLEXITY);
uint256 constant EXPECTED_GAS_SPENT_FOR_MOVING = $$(EXPECTED_GAS_SPENT_FOR_MOVING);

uint256 constant PRIORITY_MODE_MINUMUM_PROCESSED_COMPLEXITY = 0;
uint256 constant PRIORITY_MODE_MAXIMUM_PROCESSED_COMPLEXITY = 10;

uint128 constant PRIORITY_MODE_AUCTION_TIME = $$(PRIORITY_MODE_AUCTION_TIME);
uint128 constant PRIORITY_MODE_ACTION_WINNER_PROVING_TIME = $$(PRIORITY_MODE_ACTION_WINNER_PROVING_TIME);
uint128 constant PRIORITY_MODE_DELAY_SUBEPOCH_TIME = $$(PRIORITY_MODE_DELAY_SUBEPOCH_TIME);

uint256 constant SSTOREZeroSlotGasCost = 20_000;
uint256 constant SSTORENonZeroSlotGasCost = 5_000;

/// @dev Min deplay between diamond freezes
uint256 constant DELAY_BETWEEN_DIAMOND_FREEZES = 0;

/// @dev Min time (in seconds) after which contract can be unfreezed
uint256 constant MIN_DIAMOND_FREEZE_TIME = $$(MIN_DIAMOND_FREEZE_TIME);

/// @dev Time (in seconds) after which contract can be unfreezed by anyone
uint256 constant MAX_DIAMOND_FREEZE_TIME = $$(MAX_DIAMOND_FREEZE_TIME);

/// @dev Number of security council members that should approve emergency upgrade
uint256 constant SECURITY_COUNCIL_APPROVALS_FOR_EMERGENCY_UPGRADE = $$(
    SECURITY_COUNCIL_APPROVALS_FOR_EMERGENCY_UPGRADE
);

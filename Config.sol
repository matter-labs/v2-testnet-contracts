pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



bytes32 constant EMPTY_STRING_KECCAK = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

/// @dev a value that is added to the address of the contract account from which the priority operation is requested.
uint160 constant ADDRESS_ALIAS_OFFSET = uint160(0x1111000000000000000000000000000000001111);

/// @dev ERC20 tokens and ETH withdrawals gas limit, used only for complete withdrawals
uint256 constant WITHDRAWAL_GAS_LIMIT = 100000;

/// @dev Fixed address of ETH in zkSync network. Weird case is to pass the checksum check.
address constant ZKSYNC_ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

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
uint256 constant UPGRADE_NOTICE_PERIOD = 0;

/// @dev Timestamp - seconds since unix epoch
uint256 constant COMMIT_TIMESTAMP_NOT_OLDER = 24 hours;

/// @dev Maximum available error between real commit block timestamp and analog used in the verifier (in seconds)
/// @dev Must be used cause miner's `block.timestamp` value can differ on some small value (as we know - 15 seconds)
uint256 constant COMMIT_TIMESTAMP_APPROXIMATION_DELTA = 15 minutes;

/// @dev Bit mask to apply for verifier public input before verifying.
uint256 constant INPUT_MASK = 14474011154664524427946373126085988481658748083205070504932198000989141204991;

/// @dev The time it takes for the operator to add a priority operation from the buffer to the heap.
uint256 constant PRIORITY_BUFFER_EXPIRATION = 0; //3 days / BLOCK_PERIOD;

// TODO: reestimate this value!
uint256 constant DEPOSIT_PRIORITY_OPERATION_GAS_COST = 1;
uint256 constant WITHDRAW_PRIORITY_OPERATION_GAS_COST = 1;
uint256 constant ADD_TOKEN_PRIORITY_OPERATION_GAS_COST = 1;
uint256 constant DEPLOY_CONTRACT_WPRIORITY_OPERATION_GAS_COST = 1;
uint256 constant EXECUTE_CONTRACT_PRIORITY_OPERATION_GAS_COST = 1;

uint96 constant PRIORITY_TRANSACTION_FEE_BURN_PERCENTAGE = 2;
uint96 constant PRIORITY_TRANSACTION_FEE_BURN_COEF = 100 / PRIORITY_TRANSACTION_FEE_BURN_PERCENTAGE;

uint256 constant EXPECTED_PROCESSED_COMPLEXITY = 0;
uint256 constant EXPECTED_GAS_SPENT_FOR_MOVING = 0;

uint256 constant PRIORITY_MODE_MINUMUM_PROCESSED_COMPLEXITY = 0;
uint256 constant PRIORITY_MODE_MAXIMUM_PROCESSED_COMPLEXITY = 10;

uint128 constant PRIORITY_MODE_AUCTION_TIME = 0;
uint128 constant PRIORITY_MODE_ACTION_WINNER_PROVING_TIME = 0;
uint128 constant PRIORITY_MODE_DELAY_SUBEPOCH_TIME = 0;

uint256 constant SSTOREZeroSlotGasCost = 20_000;
uint256 constant SSTORENonZeroSlotGasCost = 5_000;

/// @dev Max first-class citizen token name length
uint256 constant MAX_TOKEN_NAME_LENGTH_BYTES = 64;

/// @dev Max first-class citizen token symbol length
uint256 constant MAX_TOKEN_SYMBOL_LENGTH_BYTES = 64;

/// @dev Min deplay between diamond freezes
uint256 constant DELAY_BETWEEN_DIAMOND_FREEZES = 0;

/// @dev Min time (in seconds) after which contract can be unfreezed
uint256 constant MIN_DIAMOND_FREEZE_TIME = 0;

/// @dev Time (in seconds) after which contract can be unfreezed by anyone
uint256 constant MAX_DIAMOND_FREEZE_TIME = 0;

/// @dev Number of security council members that should approve emergency upgrade
uint256 constant SECURITY_COUNCIL_APPROVALS_FOR_EMERGENCY_UPGRADE = 0;

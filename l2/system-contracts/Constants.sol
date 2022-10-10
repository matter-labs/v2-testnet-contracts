// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "./interfaces/IAccountCodeStorage.sol";
import "./interfaces/INonceHolder.sol";
import "./interfaces/IContractDeployer.sol";
import "./interfaces/IKnownCodesStorage.sol";
import "./interfaces/IImmutableSimulator.sol";
import "./interfaces/IEthToken.sol";
import "./interfaces/IL1Messenger.sol";
import "./interfaces/ISystemContext.sol";
import "./BootloaderUtilities.sol";

uint160 constant SYSTEM_CONTRACTS_OFFSET = 0x8000; // 2^15
uint160 constant MAX_SYSTEM_CONTRACT_ADDRESS = 0xffff; // 2^16 - 1

address constant ECRECOVER_SYSTEM_CONTRACT = address(0x01);
address constant SHA256_SYSTEM_CONTRACT = address(0x02);

address payable constant BOOTLOADER_FORMAL_ADDRESS = payable(address(SYSTEM_CONTRACTS_OFFSET + 0x01));
IAccountCodeStorage constant ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT = IAccountCodeStorage(address(SYSTEM_CONTRACTS_OFFSET + 0x02));
INonceHolder constant NONCE_HOLDER_SYSTEM_CONTRACT = INonceHolder(address(SYSTEM_CONTRACTS_OFFSET + 0x03));
IKnownCodesStorage constant KNOWN_CODE_STORAGE_CONTRACT = IKnownCodesStorage(address(SYSTEM_CONTRACTS_OFFSET + 0x04));
IImmutableSimulator constant IMMUTABLE_SIMULATOR_SYSTEM_CONTRACT = IImmutableSimulator(address(SYSTEM_CONTRACTS_OFFSET + 0x05));
IContractDeployer constant DEPLOYER_SYSTEM_CONTRACT = IContractDeployer(address(SYSTEM_CONTRACTS_OFFSET + 0x06));

// A contract that is allowed to deploy any codehash
// on any address. To be used only during an upgrade.
address constant FORCE_DEPLOYER = address(SYSTEM_CONTRACTS_OFFSET + 0x07);
IL1Messenger constant L1_MESSENGER_CONTRACT = IL1Messenger(address(SYSTEM_CONTRACTS_OFFSET + 0x08));
address constant MSG_VALUE_SYSTEM_CONTRACT = address(SYSTEM_CONTRACTS_OFFSET + 0x09);

IEthToken constant ETH_TOKEN_SYSTEM_CONTRACT = IEthToken(address(SYSTEM_CONTRACTS_OFFSET + 0x0a));

address constant KECCAK256_SYSTEM_CONTRACT = address(SYSTEM_CONTRACTS_OFFSET + 0x10);

ISystemContext constant SYSTEM_CONTEXT_CONTRACT = ISystemContext(payable(address(SYSTEM_CONTRACTS_OFFSET + 0x0b)));

BootloaderUtilities constant BOOTLOADER_UTILITIES = BootloaderUtilities(address(SYSTEM_CONTRACTS_OFFSET + 0x0c));

bytes32 constant DEFAULT_ACCOUNT_CODE_HASH = 0x00;

// The number of bytes that are published during the contract deployment
// in addition to the bytecode itself.
uint256 constant BYTECODE_PUBLISHING_OVERHEAD = 100;

uint256 constant MSG_VALUE_SIMULATOR_IS_SYSTEM_BIT = 2**128;

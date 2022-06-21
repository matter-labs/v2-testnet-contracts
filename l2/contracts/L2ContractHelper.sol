// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

interface IL2Messanger {
    function sendToL1(bytes memory _message) external returns (bytes32);
}

interface IContractDeployer {
    function create2(
        bytes32 _salt,
        bytes32 _bytecodeHash,
        uint256 _value,
        bytes calldata _input
    ) external;
}

uint160 constant SYSTEM_CONTRACTS_OFFSET = 0x8000; // 2^15

address constant BOOTLOADER_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x01);
address constant VALUE_SIMULATOR_SYSTEM_CONTRACT_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x09);
IL2Messanger constant L2_MESSANGER = IL2Messanger(address(SYSTEM_CONTRACTS_OFFSET + 0x08));

library L2ContractHelper {
    bytes32 constant CREATE2_PREFIX = keccak256("zksyncCreate2");

    function sendMessageToL1(bytes memory _message) internal returns (bytes32) {
        return L2_MESSANGER.sendToL1(_message);
    }

    function computeCreate2Address(
        address _sender,
        bytes32 _salt,
        bytes32 _bytecodeHash,
        bytes32 _constructorInputHash
    ) internal pure returns (address) {
        bytes32 senderBytes = bytes32(uint256(uint160(_sender)));
        bytes32 data = keccak256(
            bytes.concat(CREATE2_PREFIX, senderBytes, _salt, _bytecodeHash, _constructorInputHash)
        );

        return address(uint160(uint256(data)));
    }
}

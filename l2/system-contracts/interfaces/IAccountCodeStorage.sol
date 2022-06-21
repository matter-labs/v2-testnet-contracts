// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

interface IAccountCodeStorage {
    function storeCodeHash(address _address, bytes32 _hash) external;

    function getRawCodeHash(address _address) external view returns (bytes32 codeHash);

    function getCodeHash(address _address) external returns (bytes32 codeHash);
    
    function getCodeSize(address _address) external returns (uint256 codeSize);
}

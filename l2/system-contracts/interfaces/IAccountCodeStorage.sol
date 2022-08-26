// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

interface IAccountCodeStorage {
    function storeCodeHash(address _address, bytes32 _hash) external;

    function getRawCodeHash(address _address) external view returns (bytes32 codeHash);

    function getCodeHash(uint256 _input) external returns (bytes32 codeHash);
    
    function getCodeSize(uint256 _input) external returns (uint256 codeSize);
}

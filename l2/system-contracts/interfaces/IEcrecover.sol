// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

interface IEcrecover {
    function ecrecover_(bytes32 _hash, bytes32 _r, bytes32 _s, uint8 _v) external returns (address);
}

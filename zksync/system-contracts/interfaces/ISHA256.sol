// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

interface ISHA256 {
    function sha256_(bytes memory _bytes) external returns (bytes32);
}

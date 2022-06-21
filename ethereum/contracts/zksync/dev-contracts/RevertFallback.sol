// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

contract RevertFallback {
    fallback() external payable {
        revert();
    }
}

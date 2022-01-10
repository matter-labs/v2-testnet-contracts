pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



contract RevertFallback {
    fallback() external payable {
        revert();
    }
}

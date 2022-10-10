// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "../TransactionHelper.sol";

interface IBootloaderUtilities {
    function getTransactionHash(Transaction calldata _transaction) external view returns (bytes32);
}

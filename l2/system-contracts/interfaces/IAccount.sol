// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import '../TransactionHelper.sol';

interface IAccount {
	function validateTransaction(Transaction calldata _transaction) external payable;

	function executeTransaction(Transaction calldata _transaction) external payable;

	function executeTransactionFromOutside(Transaction calldata _transaction) external payable;

	function payForTransaction(Transaction calldata _transaction) external payable;

	function prePaymaster(Transaction calldata _transaction) external payable;
}

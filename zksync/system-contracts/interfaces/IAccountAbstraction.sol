// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import '../TransactionHelper.sol';

interface IAccountAbstraction {
	function validateTransaction(Transaction calldata _transaction) external payable;

	function executeTransaction(Transaction calldata _transaction) external payable;

	function executeTransactionFromOutside(Transaction calldata _transaction) external payable;
}

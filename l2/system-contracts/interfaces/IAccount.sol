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

bytes4 constant ERC165_ACCOUNT_INTERFACE_ID = IAccount.validateTransaction.selector ^
	IAccount.executeTransaction.selector ^
	IAccount.executeTransactionFromOutside.selector ^
	IAccount.payForTransaction.selector ^
	IAccount.prePaymaster.selector;

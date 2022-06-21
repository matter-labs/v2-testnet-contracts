// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import './Constants.sol';
import './TransactionHelper.sol';

import './interfaces/IAccountAbstraction.sol';

/**
 * @author Matter Labs
 * @notice The default implementation of account abstraction.
 * @dev The bytecode of the contract is set by default for all addresses for which no other bytecodes are deployed.
 * @notice If caller is not a bootloader always returns empty return data on call, just like EOA do.
 */
contract DefaultAccountAbstraction is IAccountAbstraction {
	using TransactionHelper for Transaction;

	// bytes4(keccak256("isValidSignature(bytes32,bytes)")
	bytes4 constant EIP1271_SUCCESS_RETURN_VALUE = 0x1626ba7e;

	/**
	 * @dev Simulate behaivour of the EOA if caller is not the bootloader.
	 * Essentially, for all non-bootloader caller halt the execution with empty return data.
	 * If all functions will use this modifier AND the contract will implement an empty payable fallback()
	 * then the contract will be indistinguishable from the EOA when called.
	 */
	modifier ignoreNonBootloader() {
		if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
			// If function was called outside of the bootloader, behave like an EOA.
			assembly {
				return(0, 0)
			}
		}
		// Continure execution if called from the bootloader.
		_;
	}

	function validateTransaction(Transaction calldata _transaction) external payable override ignoreNonBootloader {
		_validateTransaction(_transaction);
	}

	function _validateTransaction(Transaction calldata _transaction) internal {
		NONCE_HOLDER_SYSTEM_CONTRACT.incrementNonceIfEquals(_transaction.reserved[0]);
		bytes32 txHash = _transaction.encodeHash();

		require(_isValidSignature(txHash, _transaction.signature) == EIP1271_SUCCESS_RETURN_VALUE);
	}

	function executeTransaction(Transaction calldata _transaction) external payable override ignoreNonBootloader {
		_execute(_transaction);
	}

	function executeTransactionFromOutside(Transaction calldata _transaction) external payable override ignoreNonBootloader {
		_validateTransaction(_transaction);
		_execute(_transaction);
	}

	function _execute(Transaction calldata _transaction) internal {
		uint256 to = _transaction.to;
		uint256 value = _transaction.reserved[1];
		bytes memory data = _transaction.data;

		bool success;
		assembly {
			success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
		}
		require(success);
	}

	function _isValidSignature(bytes32 _hash, bytes memory _signature) internal view returns (bytes4) {
		require(_signature.length == 65, 'Signature length is incorrect');
		uint8 v;
		bytes32 r;
		bytes32 s;
		// Signature loading code
		// we jump 32 (0x20) as the first slot of bytes contains the length
		// we jump 65 (0x41) per signature
		// for v we load 32 bytes ending with v (the first 31 come from s) then apply a mask
		assembly {
			r := mload(add(_signature, 0x20))
			s := mload(add(_signature, 0x40))
			v := and(mload(add(_signature, 0x41)), 0xff)
		}
		require(v == 27 || v == 28);

		address recoveredAddress = ecrecover(_hash, v, r, s);

		require(recoveredAddress == address(this));

		return EIP1271_SUCCESS_RETURN_VALUE;
	}

	fallback() external payable {
		// fallback of default AA shouldn't be called by bootloader under no circumstances 
		assert(msg.sender != BOOTLOADER_FORMAL_ADDRESS);		
		
		// If the contract is called directly, behave like an EOA
	}
}

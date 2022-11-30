// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import './Constants.sol';
import './SystemContractHelper.sol';
import './TransactionHelper.sol';

import './interfaces/IAccount.sol';

/**
 * @author Matter Labs
 * @notice The default implementation of account.
 * @dev The bytecode of the contract is set by default for all addresses for which no other bytecodes are deployed.
 * @notice If the caller is not a bootloader always returns empty return data on call, just like EOA does.
 */
contract DefaultAccount is IAccount {
	using TransactionHelper for *;

	/// @dev bytes4(keccak256("isValidSignature(bytes32,bytes)"))
	bytes4 constant EIP1271_SUCCESS_RETURN_VALUE = 0x1626ba7e;

	/**
	 * @dev Simulate the behavior of the EOA if the caller is not the bootloader.
	 * Essentially, for all non-bootloader callers halt the execution with empty return data.
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
		// Continue execution if called from the bootloader.
		_;
	}

	/// @notice Validates the transaction & increments nonce. 
	/// @dev The transaction is considered accepted by the account if 
	/// the call to this function by the bootloader does not revert 
	/// and the nonce has been set as used.
	/// @param _suggestedSignedHash The suggested hash of the transaction to be signed by the user.
	/// This is the hash that is signed by the EOA by default.
	/// @param _transaction The transaction structure itself.
	/// @dev Besides the params above, it also accepts unused first paramter "_txHash", which
	/// is the unique (canonical) hash of the transaction.  
	function validateTransaction(
		bytes32, // _txHash
		bytes32 _suggestedSignedHash, 
		Transaction calldata _transaction
	) external payable override ignoreNonBootloader {
		_validateTransaction(_suggestedSignedHash, _transaction);
	}

	/// @notice Inner method for validating transaction and increasing the nonce
	/// @param _suggestedSignedHash The hash of the transaction signed by the EOA
	/// @param _transaction The transaction.
	function _validateTransaction(bytes32 _suggestedSignedHash, Transaction calldata _transaction) internal {
		// Note, that nonce holder can only be called with "isSystem" flag.
		SystemContractsCaller.systemCallWithPropagatedRevert(
			uint32(gasleft()),
			address(NONCE_HOLDER_SYSTEM_CONTRACT),
			0,
			abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.reserved[0]))
		);
		
		bytes32 txHash;

		// Even though for the transaction types present in the system right now,
		// we always provide the suggested signed hash, this should not be 
		// always expected. In case the bootloader has no clue what the default hash 
		// is, the bytes32(0) will be supplied.
		if(_suggestedSignedHash == bytes32(0)) {
			txHash = _transaction.encodeHash();
		} else {
			txHash = _suggestedSignedHash;
		}

		// The fact there is are enough balance for the account
		// should be checked explicitly to prevent user paying for fee for a
		// transaction that wouldn't be included on Ethereum.
		uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
		require(totalRequiredBalance <= address(this).balance, "Not enough balance for fee + value");

		require(_isValidSignature(txHash, _transaction.signature) == EIP1271_SUCCESS_RETURN_VALUE, "Invalid signature");
	}
	
	/// @notice Method called by the bootloader to execute the transaction.
	/// @param _transaction The transaction to execute.
	/// @dev It also accepts unused _txHash and _suggestedSignedHash parameters: 
	/// the unique (canonical) hash of the transaction and the suggested signed 
	/// hash of the transaction.
	function executeTransaction(
		bytes32, // _txHash
		bytes32, // _suggestedSignedHash 
		Transaction calldata _transaction
	) external payable override ignoreNonBootloader {
		_execute(_transaction);
	}

	/// @notice Method that should be used to initiate a transaction from this account 
	/// by an external call. This is not mandatory, but should be implemented so that
	/// it is always possible to execute transaction from L1 for this account.
	/// @dev This method is basically validate + execute.
	/// @param _transaction The transaction to execute.
	function executeTransactionFromOutside(Transaction calldata _transaction) external payable override ignoreNonBootloader {
		// The account recalculate the hash on its own
		_validateTransaction(bytes32(0), _transaction);
		_execute(_transaction);
	}

	/// @notice Inner method for executing a transaction.
	/// @param _transaction The transaction to execute.
	function _execute(Transaction calldata _transaction) internal {
		address to = address(uint160(_transaction.to));
		uint256 value = _transaction.reserved[1];
		require(address(this).balance >= value, "Not enough balance to execute");

		bytes memory data = _transaction.data;

		if(to == address(DEPLOYER_SYSTEM_CONTRACT)) {
			// Note, that the deployer contract can only be called 
			// with a "systemCall" flag.
			SystemContractsCaller.systemCall(
				uint32(gasleft()),
				to,
				uint128(_transaction.reserved[1]), // By convention, reserved[1] is `value`
				_transaction.data
			);
		} else {
			assembly {
				let success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)

				// The returned revertReason will be available on the server
				// side as the revert reason of the transaction.
				if iszero(success) {
					let size := returndatasize()
					returndatacopy(0, 0, size)
					revert(0, size)
				}
			}
		}
	}

	/// @notice Validation that the ECDSA signature of the transaction is correct.
	/// @param _hash The hash of the transaction to be signed.
	/// @param _signature The signature of the transaction.
	/// @return EIP1271_SUCCESS_RETURN_VALUE if the signaure is correct. It reverts otherwise.
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
		require(v == 27 || v == 28, "v is neither 27 nor 28");

		address recoveredAddress = ecrecover(_hash, v, r, s);

		if (recoveredAddress == address(this) && recoveredAddress != address(0)) {
			return EIP1271_SUCCESS_RETURN_VALUE;
		} else {
			return 0;
		}
	}

	/// @notice Method for paying the bootloader for the transaction.
	/// @param _transaction The transaction for which the fee is paid.
	/// @dev It also accepts unused _txHash and _suggestedSignedHash parameters: 
	/// the unique (canonical) hash of the transaction and the suggested signed 
	/// hash of the transaction.
	function payForTransaction(
		bytes32, // _txHash
		bytes32, // _suggestedSignedHash
		Transaction calldata _transaction
	) external payable ignoreNonBootloader {
		bool success = _transaction.payToTheBootloader();
		require(success, "Failed to pay the fee to the operator");
	}


	/// @notice Method, where the user should prepare for the transaction to be
	/// paid for by a paymaster. 
	/// @dev Here, the account should set the allowance for the smart contracts
	/// @param _transaction The transaction.
	/// @dev It also accepts unused _txHash and _suggestedSignedHash parameters: 
	/// the unique (canonical) hash of the transaction and the suggested signed 
	/// hash of the transaction.
	function prePaymaster(
		bytes32, // _txHash
		bytes32, // _suggestedSignedHash
		Transaction calldata _transaction
	) external payable ignoreNonBootloader {
		_transaction.processPaymasterInput();
	}
 

	fallback() external {
		// fallback of default account shouldn't be called by bootloader under no circumstances 
		assert(msg.sender != BOOTLOADER_FORMAL_ADDRESS);		
		
		// If the contract is called directly, behave like an EOA
	}

	receive() external payable {
		// We allow bootloader calling this contract with zero calldata,
		// since this transaction may be used by the bootloader to 
		// transfer the fee to the operator. 
		if (msg.sender == BOOTLOADER_FORMAL_ADDRESS) {
			uint256 calldataSize;
			assembly {
				calldataSize := calldatasize()
			}
			require(calldataSize == 0, "Bootloader should only `receive` with no calldata");
		}
		
		// If the contract is called directly, behave like an EOA
	}
}

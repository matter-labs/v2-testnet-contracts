// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import './RLPEncoder.sol';
import './Constants.sol';

// TODO: change it to the `0x80`, must be changed atomically with the server.
/// @dev Denotes the first byte of the special zkSync's EIP-712-signed transaction.
uint8 constant EIP_712_TX_TYPE = 0x71;

/// @dev Denotes the first byte of some legacy transaction, which type is unknown to the server.
uint8 constant LEGACY_TX_TYPE = 0x0;

struct Transaction {
	uint8 txType;
	uint256 from;
	uint256 to;
	uint256 feeToken;
	uint256 ergsLimit;
	uint256 ergsPerPubdataByteLimit;
	uint256 ergsPrice;
	// In the future, we might want to add some
	// new fields to the struct. The `txData` struct
	// is to be passed to AA and any changes to its structure
	// would mean a breaking change to these AAs. In order to prevent this,
	// we should keep some fields as "reserved".
	// It is also recommneded that their length is fixed, since
	// it would allow easier proof integration (in case we will need
	// some special circuit for preprocessing transactions).
	uint256[6] reserved;
	bytes data;
	bytes signature;
	// Reserved dynamic type for the future use-case. Using it should be avoided,
	// But it is still here, just in case we want to enable some additional functionality.
	bytes reservedDynamic;
}

library TransactionHelper {
	/// @notice The EIP-712 typehash for the contract's domain
	bytes32 constant EIP712_DOMAIN_TYPEHASH = keccak256('EIP712Domain(string name,string version,uint256 chainId)');

	// TODO: migrate to this type once the backend is ready
	bytes32 constant EIP712_TRANSACTION_TYPE_HASH =
		keccak256(
			'Transaction(uint8 txType,uint256 to,uint256 value,bytes data,uint256 feeToken,uint256 ergsLimit,uint256 ergsPerPubdataByteLimit,uint256 ergsPrice,uint256 nonce)'
		);

	function encodeHash(Transaction calldata _transaction) internal view returns (bytes32 resultHash) {
		if (_transaction.txType == LEGACY_TX_TYPE) {
			resultHash = _encodeHashLegacyTx(_transaction);
		} else if (_transaction.txType == EIP_712_TX_TYPE) {
			resultHash = _encodeHashEIP712Tx(_transaction);
		} else {
			// Currently no other transaction types are supported.
			// Any new transaction types will be processed in a similar manner.
			revert();
		}
	}

	/// @notice encode hash of the zkSync native transaction type.
	/// @return keccak256 of the EIP-712 encoded representation of transaction
	function _encodeHashEIP712Tx(Transaction calldata _transaction) private view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                EIP712_TRANSACTION_TYPE_HASH,
                _transaction.txType,
                _transaction.to,
                _transaction.reserved[1],
                keccak256(_transaction.data),
                _transaction.feeToken,
                _transaction.ergsLimit,
                _transaction.ergsPerPubdataByteLimit,
                _transaction.ergsPrice,
                _transaction.reserved[0]
			)
		);

		bytes32 domainSeparator = keccak256(abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256('zkSync'), keccak256('2'), _getChainId()));

		return keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
	}

	/// @notice encode hash of the legacy transaction type.
	/// @return keccak256 of the serialized RLP encoded representation of transaction
	function _encodeHashLegacyTx(Transaction calldata _transaction) private view returns (bytes32) {
		// Hash of legacy transactions are encoded as one of the:
		// - RLP(nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0)
		// - RLP(nonce, gasPrice, gasLimit, to, value, data)
		//
		// In this RLP encoding, only one higher list appears, so we encode each element
		// inside list and then concatenate the length of all elements with them.

		bytes memory encodedNonce = RLPEncoder.encodeUint256(_transaction.reserved[0]);
		// Encode `gasPrice` and `gasLimit` together to prevent "stack too deep error".
		bytes memory encodedGasParam;
		{
			bytes memory encodedGasPrice = RLPEncoder.encodeUint256(_transaction.ergsPrice);
			bytes memory encodedGasLimit = RLPEncoder.encodeUint256(_transaction.ergsLimit);
			encodedGasParam = bytes.concat(encodedGasPrice, encodedGasLimit);
		}

		bytes memory encodedTo = RLPEncoder.encodeAddress(address(uint160(_transaction.to)));
		bytes memory encodedValue = RLPEncoder.encodeUint256(_transaction.reserved[1]);
		// Encode only the length of the transaction data, and not the data itself,
		// so as not to copy to memory a potentially huge transaction data twice.
		bytes memory encodedDataLength;
		{
			uint256 txDataLen = _transaction.data.length;
			if (txDataLen != 1) {
				// If the length is not equal to one, then only using the length can it be encoded definitely.
				encodedDataLength = RLPEncoder.encodeNonSingleBytesLen(txDataLen);
			} else if (_transaction.data[0] >= 0x80) {
				// If input is a byte in [0x80, 0xff] range, RLP encoding will concatenates 0x81 with the byte.
				encodedDataLength = hex'81';
			}
			// Otherwise the length is not encoded at all.
		}

		// Encode `chainId` according to EIP-155, but only if the `chainId` is specified in the transaction.
		bytes memory encodedChainId;
		if (_transaction.reserved[2] != 0) {
			// TODO: calculate RLP encoded chainId on compiler time
			encodedChainId = bytes.concat(RLPEncoder.encodeUint256(_getChainId()), hex'80_80');
		}

		bytes memory encodedListLength;
		unchecked {
			uint256 listLength = encodedNonce.length +
				encodedGasParam.length +
				encodedTo.length +
				encodedValue.length +
				encodedDataLength.length +
				_transaction.data.length +
				encodedChainId.length;

			encodedListLength = RLPEncoder.encodeListLen(listLength);
		}

		return
			keccak256(
				bytes.concat(
					encodedListLength,
					encodedNonce,
					encodedGasParam,
					encodedTo,
					encodedValue,
					encodedDataLength,
					_transaction.data,
					encodedChainId
				)
			);
	}

	function _getChainId() internal view returns(uint256 chainId) { 
		chainId = CHAIN_ID_SIMULATOR.chainId();
	}
}

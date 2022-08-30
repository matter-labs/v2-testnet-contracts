// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import './RLPEncoder.sol';
import './Constants.sol';
import "./interfaces/IERC20.sol";
import "./interfaces/IPaymasterFlow.sol";

// TODO: change it to the `0x80`, must be changed atomically with the server.
/// @dev Denotes the first byte of the special zkSync's EIP-712-signed transaction.
uint8 constant EIP_712_TX_TYPE = 0x71;

/// @dev Denotes the first byte of some legacy transaction, which type is unknown to the server.
uint8 constant LEGACY_TX_TYPE = 0x0;
uint8 constant EIP_1559_TX_TYPE = 0x02;

struct Transaction {
	uint256 txType;
	uint256 from;
	uint256 to;
	uint256 ergsLimit;
	uint256 ergsPerPubdataByteLimit;
	uint256 maxFeePerErg;
	uint256 maxPriorityFeePerErg;
	uint256 paymaster;
	// In the future, we might want to add some
	// new fields to the struct. The `txData` struct
	// is to be passed to account and any changes to its structure
	// would mean a breaking change to these accounts. In order to prevent this,
	// we should keep some fields as "reserved".
	// It is also recommneded that their length is fixed, since
	// it would allow easier proof integration (in case we will need
	// some special circuit for preprocessing transactions).
	uint256[6] reserved;
	bytes data;
	bytes signature;
	bytes32[] factoryDeps;
	bytes paymasterInput;
	// Reserved dynamic type for the future use-case. Using it should be avoided,
	// But it is still here, just in case we want to enable some additional functionality.
	bytes reservedDynamic;
}

library TransactionHelper {
	/// @notice The EIP-712 typehash for the contract's domain
	bytes32 constant EIP712_DOMAIN_TYPEHASH = keccak256('EIP712Domain(string name,string version,uint256 chainId)');

	bytes32 constant EIP712_TRANSACTION_TYPE_HASH =
		keccak256(
			'Transaction(uint256 txType,uint256 from,uint256 to,uint256 ergsLimit,uint256 ergsPerPubdataByteLimit,uint256 maxFeePerErg,uint256 maxPriorityFeePerErg,uint256 paymaster,uint256 nonce,uint256 value,bytes data,bytes32[] factoryDeps,bytes paymasterInput)'
		);

	function isEthToken(uint256 _addr) internal pure returns (bool){
		return _addr == uint256(uint160(address(ETH_TOKEN_SYSTEM_CONTRACT))) || _addr == 0;
	}

	function encodeHash(Transaction calldata _transaction) internal view returns (bytes32 resultHash) {
		if (_transaction.txType == LEGACY_TX_TYPE) {
			resultHash = _encodeHashLegacyTx(_transaction);
		} else if (_transaction.txType == EIP_712_TX_TYPE) {
			resultHash = _encodeHashEIP712Tx(_transaction);
        } else if (_transaction.txType == EIP_1559_TX_TYPE) {
            resultHash = _encodeHashEIP1559Tx(_transaction);
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
                _transaction.from,
                _transaction.to,
                _transaction.ergsLimit,
                _transaction.ergsPerPubdataByteLimit,
                _transaction.maxFeePerErg,
                _transaction.maxPriorityFeePerErg,
                _transaction.paymaster,
                _transaction.reserved[0],
                _transaction.reserved[1],
                keccak256(_transaction.data),
                keccak256(abi.encodePacked(_transaction.factoryDeps)),
                keccak256(_transaction.paymasterInput)
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
			bytes memory encodedGasPrice = RLPEncoder.encodeUint256(_transaction.maxFeePerErg);
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

    function _encodeHashEIP1559Tx(Transaction calldata _transaction) private view returns (bytes32) {
        // Hash of EIP1559 transactions is encoded the following way:
        // H(0x02 || RLP(chain_id, nonce, max_priority_fee_per_gas, max_fee_per_gas, gas_limit, destination, amount, data, access_list))
        // 
        // Note, that on zkSync access lists are not supported and should always be empty.

        // Encode all fixed-length params to avoid "stack too deep error"
        bytes memory encodedFixedLengthParams;
        {
            bytes memory encodedChainId = RLPEncoder.encodeUint256(_getChainId());
            bytes memory encodedNonce = RLPEncoder.encodeUint256(_transaction.reserved[0]);
            bytes memory encodedMaxPriorityFeePerGas = RLPEncoder.encodeUint256(_transaction.maxPriorityFeePerErg);
            bytes memory encodedMaxFeePerGas = RLPEncoder.encodeUint256(_transaction.maxFeePerErg);
            bytes memory encodedGasLimit = RLPEncoder.encodeUint256(_transaction.ergsLimit);
            bytes memory encodedTo = RLPEncoder.encodeAddress(address(uint160(_transaction.to)));
            bytes memory encodedValue = RLPEncoder.encodeUint256(_transaction.reserved[1]);
            encodedFixedLengthParams = bytes.concat(
                encodedChainId, 
                encodedNonce, 
                encodedMaxPriorityFeePerGas, 
                encodedMaxFeePerGas, 
                encodedGasLimit, 
                encodedTo, 
                encodedValue
            );
        }

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

        // On zkSync, access lists are always zero length (at least for now).
        bytes memory encodedAccessListLength = RLPEncoder.encodeListLen(0);

        bytes memory encodedListLength;
        unchecked {
            uint256 listLength = 
                encodedFixedLengthParams.length +
                encodedDataLength.length +
                _transaction.data.length +
                encodedAccessListLength.length;

            encodedListLength = RLPEncoder.encodeListLen(listLength);
        }

        return
            keccak256(
                bytes.concat(
                    '\x02',
                    encodedListLength,
                    encodedFixedLengthParams,
                    encodedDataLength,
                    _transaction.data,
                    encodedAccessListLength
                )
            );
    }

	function _getChainId() internal view returns(uint256 chainId) { 
		chainId = SYSTEM_CONTEXT_CONTRACT.chainId();
	}

	function processPaymasterInput(Transaction calldata _transaction) internal {
		require(_transaction.paymasterInput.length >= 4, "The standard paymaster input must be at least 4 bytes long");

		bytes4 paymasterInputSelector = bytes4(_transaction.paymasterInput[0:4]);
		if (paymasterInputSelector == IPaymasterFlow.approvalBased.selector) {
			// While the actual data consists of address, uint256 and bytes data, 
			// the data is needed only for the paymaster, so we ignore it here for the sake of optimization
			(address token, uint256 minAllowance) = abi.decode(_transaction.paymasterInput[4:68], (address, uint256));
			address paymaster = address(uint160(_transaction.paymaster));

			uint256 currentAllowance = IERC20(token).allowance(address(this), paymaster);
			if (currentAllowance < minAllowance) {
				// Some tokens, e.g. USDT require that the allowance is firsty set to zero 
				// and only then updated to the new value.
				
				IERC20(token).approve(paymaster, 0);
				IERC20(token).approve(paymaster, minAllowance);
			}
		} else if (paymasterInputSelector == IPaymasterFlow.general.selector) {
			// Do nothing. General(bytes) paymaster flow means that the paymaster must interpret these bytes on his own.
		} else {
			revert("Unsupported paymaster flow");
		}
	}

	function payToTheBootloader(Transaction calldata _transaction) internal returns (bool success){
		address bootloaderAddr = BOOTLOADER_FORMAL_ADDRESS;
		uint256 amount = _transaction.maxFeePerErg * _transaction.ergsLimit;

		assembly {
			success := call(
				gas(),
				bootloaderAddr,
				amount,
				0,
				0,
				0,
				0
			)
		}
	}
}

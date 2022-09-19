pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../interfaces/IMailbox.sol";
import "../libraries/Merkle.sol";
import "../libraries/PriorityQueue.sol";
import "../Storage.sol";
import "../../common/L2ContractHelper.sol";
import "./Base.sol";

/// @title zkSync Mailbox contract providing interfaces for L1 <-> L2 interaction.
/// @author Matter Labs
contract MailboxFacet is Base, IMailbox {
    using PriorityQueue for PriorityQueue.Queue;

    function proveL2MessageInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Message calldata _message,
        bytes32[] calldata _proof
    ) external view returns (bool) {
        return _proveL2LogInclusion(_blockNumber, _index, _L2MessageToLog(_message), _proof);
    }

    function proveL2LogInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) external view returns (bool) {
        return _proveL2LogInclusion(_blockNumber, _index, _log, _proof);
    }

    function _proveL2LogInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) internal view returns (bool) {
        require(_blockNumber <= s.totalBlocksExecuted, "xx");

        bytes32 hashedLog = sha256(abi.encodePacked(_log.sender, _log.key, _log.value));
        bytes32 calculatedRootHash = Merkle.calculateRoot(_proof, _index, hashedLog);
        bytes32 actualRootHash = s.l2LogsRootHashes[_blockNumber];

        return actualRootHash == calculatedRootHash;
    }

    /// @dev convert arbitrary length message to the raw l2 log
    function _L2MessageToLog(L2Message calldata _message) internal pure returns (L2Log memory) {
        return
            L2Log({
                sender: L2_TO_L1_MESSENGER,
                key: bytes32(uint256(uint160(_message.sender))),
                value: keccak256(_message.data)
            });
    }

    function l2TransactionBaseCost(
        uint256, // _gasPrice
        uint256, // _ergsLimit
        uint32 // _calldataLength
    ) public pure returns (uint256) {
        // TODO: estimate gas for L1 execute
        return 0;
    }

    function requestL2Transaction(
        address _contractL2,
        uint256 _l2Value,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) external payable nonReentrant returns (bytes32 canonicalTxHash) {
        return _requestL2Transaction(msg.sender, _contractL2, _l2Value, _calldata, _ergsLimit, _factoryDeps);
    }

    function _requestL2Transaction(
        address _sender,
        address _contractL2,
        uint256 _l2Value,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) internal returns (bytes32 canonicalTxHash) {
        uint64 expirationBlock = uint64(block.number + PRIORITY_EXPIRATION);
        uint256 txId = s.priorityQueue.head;
        // TODO: Restore after stable priority op fee modeling. (SMA-1230)
        // uint256 baseCost = l2TransactionBaseCost(tx.gasprice, _ergsLimit, uint32(_calldata.length));
        // uint256 layer2Tip = msg.value - baseCost;

        canonicalTxHash = _writePriorityOp(
            _sender,
            txId,
            _l2Value,
            _contractL2,
            _calldata,
            expirationBlock,
            _ergsLimit,
            _factoryDeps
        );
    }

    /// @notice Stores a transaction record in storage & send event about that
    function _writePriorityOp(
        address _sender,
        uint256 _txId,
        uint256 _l2Value,
        address _contractAddressL2,
        bytes calldata _calldata,
        uint64 _expirationBlock,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) internal returns (bytes32 canonicalTxHash) {
        L2CanonicalTransaction memory transaction = serializeL2Transaction(
            _txId,
            _l2Value,
            _sender,
            _contractAddressL2,
            _calldata,
            _ergsLimit,
            _factoryDeps
        );
        canonicalTxHash = keccak256(abi.encode(transaction));

        s.priorityQueue.pushBack(
            PriorityOperation({
                canonicalTxHash: canonicalTxHash,
                expirationBlock: _expirationBlock,
                layer2Tip: uint192(0) // TODO: Restore after fee modeling will be stable. (SMA-1230)
            })
        );

        // Data that needed for operator to simulate priority queue offchain
        emit NewPriorityRequest(_txId, canonicalTxHash, _expirationBlock, transaction, _factoryDeps);
    }

    /// @dev Accepts the parameters of the l2 transaction and converts it to the canonical form.
    function serializeL2Transaction(
        uint256 _txId,
        uint256 _l2Value,
        address _sender,
        address _contractAddressL2,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) public pure returns (L2CanonicalTransaction memory) {
        return
            L2CanonicalTransaction({
                txType: PRIORITY_OPERATION_L2_TX_TYPE,
                from: uint256(uint160(_sender)),
                to: uint256(uint160(_contractAddressL2)),
                ergsLimit: _ergsLimit,
                ergsPerPubdataByteLimit: uint256(1),
                maxFeePerErg: uint256(0),
                maxPriorityFeePerErg: uint256(0),
                paymaster: uint256(0),
                reserved: [uint256(_txId), _l2Value, 0, 0, 0, 0],
                data: _calldata,
                signature: new bytes(0),
                factoryDeps: _hashFactoryDeps(_factoryDeps),
                paymasterInput: new bytes(0),
                reservedDynamic: new bytes(0)
            });
    }

    /// @notice hashes the L2 bytecodes and returns them in the format in which they are processed by the bootloader
    function _hashFactoryDeps(bytes[] calldata _factoryDeps)
        internal
        pure
        returns (uint256[] memory hashedFactoryDeps)
    {
        uint256 factoryDepsLen = _factoryDeps.length;
        hashedFactoryDeps = new uint256[](factoryDepsLen);
        for (uint256 i = 0; i < factoryDepsLen; ) {
            bytes32 hashedBytecode = L2ContractHelper.hashL2Bytecode(_factoryDeps[i]);

            // Store the resulting hash sequentially in bytes.
            assembly {
                mstore(add(hashedFactoryDeps, mul(add(i, 1), 32)), hashedBytecode)
            }

            unchecked {
                ++i;
            }
        }
    }
}

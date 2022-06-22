pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../interfaces/IMailbox.sol";

import "../libraries/PriorityQueue.sol";
import "../libraries/Auction.sol";
import "../libraries/CheckpointedPrefixSum.sol";
import "../libraries/Merkle.sol";
import "../Operations.sol";
import "../Storage.sol";

import "../../common/L2ContractHelper.sol";

import "./Base.sol";

/// @title zkSync Mailbox contract providing interfaces for L1 <-> L2 interaction.
/// @author Matter Labs
contract MailboxFacet is Base, IMailbox {
    using PriorityQueue for PriorityQueue.Queue;
    using CheckpointedPrefixSum for CheckpointedPrefixSum.PrefixSum;

    function proveL2MessageInclusion(
        uint32 _blockNumber,
        uint256 _index,
        L2Message calldata _message,
        bytes32[] calldata _proof
    ) external view returns (bool) {
        return _proveL2LogInclusion(_blockNumber, _index, _L2MessageToLog(_message), _proof);
    }

    function proveL2LogInclusion(
        uint32 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) external view returns (bool) {
        return _proveL2LogInclusion(_blockNumber, _index, _log, _proof);
    }

    function _proveL2LogInclusion(
        uint32 _blockNumber,
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
        uint256 _gasPrice,
        uint256 _ergsLimit,
        uint32 _calldataLength,
        QueueType _queueType
    ) public view returns (uint256) {
        return 0;
        // TODO: estimate gas for L1 execute
        // return (EXECUTE_CONTRACT_PRIORITY_OPERATION_GAS_COST + _addPriorityOpGasCost(_queueType, _opTree)) * _gasPrice;
    }

    function requestL2Transaction(
        address _contractL2,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps,
        QueueType _queueType
    ) external payable nonReentrant returns (bytes32 canonicalTxHash) {
        return _requestL2Transaction(msg.sender, _contractL2, _calldata, _ergsLimit, _factoryDeps, _queueType);
    }

    function _requestL2Transaction(
        address _sender,
        address _contractL2,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps,
        QueueType _queueType
    ) internal returns (bytes32 canonicalTxHash) {
        require(_queueType == QueueType.Deque);

        uint64 expirationBlock = _calculateExpirationBlock(_queueType);
        uint64 txId = s.totalPriorityRequests;

        uint256 layer2Tip;
        // Preventing "stack too deep error"
        {
            uint256 baseCost = l2TransactionBaseCost(tx.gasprice, _ergsLimit, uint32(_calldata.length), _queueType);
            layer2Tip = _burnL2Tip(msg.value - baseCost, _queueType);
        }

        canonicalTxHash = _writePriorityOp(
            _sender,
            txId,
            layer2Tip,
            _contractL2,
            _calldata,
            expirationBlock,
            _ergsLimit,
            _factoryDeps,
            _queueType
        );

        if (_queueType == QueueType.Deque) {
            _pushTxToDeque(txId);
        } else if (_queueType == QueueType.HeapBuffer) {
            _pushTxToBufferHeap(txId, expirationBlock);
        } else if (_queueType == QueueType.Heap) {
            _pushTxToHeap(txId, expirationBlock);
        } else {
            revert("d"); // Unsupported queue type
        }

        s.totalPriorityRequests += 1;
    }

    /// @notice Stores a transaction record in storage & send event about that
    function _writePriorityOp(
        address _sender,
        uint64 _txId,
        uint256 _layer2Tip,
        address _contractAddressL2,
        bytes calldata _calldata,
        uint64 _expirationBlock,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps,
        QueueType _queueType
    ) internal returns (bytes32 canonicalTxHash) {
        L2CanonicalTransaction memory transaction = serializeL2Transaction(
            _txId,
            _layer2Tip,
            _sender,
            _contractAddressL2,
            _calldata,
            _ergsLimit,
            _factoryDeps
        );
        canonicalTxHash = keccak256(abi.encode(transaction));

        s.storedOperations.inner[_txId] = PriorityOperation({
            canonicalTxHash: canonicalTxHash,
            expirationBlock: _expirationBlock,
            layer2Tip: uint192(_layer2Tip)
        });

        // Data that needed for operator to simulate priority queue offchain
        emit NewPriorityRequest(_txId, canonicalTxHash, _expirationBlock, transaction, _factoryDeps);
    }

    function serializeL2Transaction(
        uint64 _txId,
        uint256 _layer2Tip,
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
                feeToken: uint256(0),
                ergsLimit: _ergsLimit,
                ergsPerPubdataByteLimit: uint256(1),
                ergsPrice: uint256(0),
                reserved: [uint256(_txId), _layer2Tip, 0, 0, 0, 0],
                data: _calldata,
                signature: new bytes(0),
                reservedDynamic: _hashFactoryDeps(_factoryDeps)
            });
    }

    /// @notice hashes the L2 bytecodes and returns them in the format in which they are processed by the bootloader
    function _hashFactoryDeps(bytes[] calldata _factoryDeps) internal pure returns (bytes memory hashedFactoryDeps) {
        uint256 factoryDepsLen = _factoryDeps.length;
        hashedFactoryDeps = new bytes(32 * factoryDepsLen);
        for (uint256 i = 0; i < factoryDepsLen; ++i) {
            bytes32 hashedBytecode = L2ContractHelper.hashL2Bytecode(_factoryDeps[i]);

            // Store the resulting hash sequentially in bytes.
            assembly {
                mstore(add(hashedFactoryDeps, mul(add(i, 1), 32)), hashedBytecode)
            }
        }
    }

    /// @notice adds a priority transaction with the given id to deque
    function _pushTxToDeque(uint64 _txId) internal {
        s.priorityQueue[OpTree.Full].pushBackToDeque(_txId);
    }

    /// @notice adds a priority transaction with the given id to buffer heap
    function _pushTxToBufferHeap(uint64 _txId, uint64 _expirationBlock) internal {
        s.expiringOpsCounter.bufferHeap[_expirationBlock] += 1;
        s.priorityQueue[OpTree.Full].pushToBufferHeap(s.storedOperations, _txId);
    }

    /// @notice adds a priority transaction with the given id to heap
    function _pushTxToHeap(uint64 _txId, uint64 _expirationBlock) internal {
        PriorityModeLib.State memory state = s.priorityModeState;
        // Block executor take operations from the heap, so this heap should be left unchanged while the operator can produce blocks.
        // Therefore user can add priority operation directly to the heap only when nobody makes blocks - delay sub epoch in priority mode.
        require(state.priorityModeEnabled && state.epoch == PriorityModeLib.Epoch.Delay, "z");

        s.expiringOpsCounter.heap[_expirationBlock] += 1;
        s.priorityQueue[OpTree.Full].pushToHeap(s.storedOperations, _txId);
    }

    /// @notice burns a proportional part of the ether if necessary
    /// @return layer2Tip the amount of ether that is left with `l2Tip` after burning
    function _burnL2Tip(uint256 _value, QueueType _queueType) internal returns (uint256 layer2Tip) {
        if (_queueType == QueueType.Deque) {
            layer2Tip = _value;
        } else {
            // It is safe to divide because the value is in WEI
            uint256 burntTip = _value / PRIORITY_TRANSACTION_FEE_BURN_COEF;
            layer2Tip = _value - burntTip;
            // Burning part of the tip fee
            Utils.burnEther(burntTip);
        }
    }

    /// @notice counts the block number up to which the priority transaction should be processed
    function _calculateExpirationBlock(QueueType _queueType) internal view returns (uint64) {
        // Expiration block is: current block number + priority expiration delta
        return
            _queueType == QueueType.HeapBuffer
                ? uint64(block.number + PRIORITY_BUFFER_EXPIRATION)
                : uint64(block.number + PRIORITY_EXPIRATION);
    }

    /// @notice calculates the cost of moving an operation from the buffer to the main queue
    function _addPriorityOpGasCost(QueueType _queueType, OpTree _opTree) internal view returns (uint256 cost) {
        // TODO: This formula is not final, but I have no idea how to do it right yet. (SMA-205)
        if (_queueType == QueueType.HeapBuffer) {
            uint256 totalHeapsHeight = uint256(s.priorityQueue[_opTree].getTotalHeapsHeight());
            cost = 2 * (totalHeapsHeight * SSTORENonZeroSlotGasCost + SSTOREZeroSlotGasCost);
        } else if (_queueType == QueueType.Heap) {
            uint256 heapHeight = uint256(s.priorityQueue[_opTree].heapSize());
            cost = 2 * (heapHeight * SSTORENonZeroSlotGasCost + SSTOREZeroSlotGasCost);
        }
    }
}

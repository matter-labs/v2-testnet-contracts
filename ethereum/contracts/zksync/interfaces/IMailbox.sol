// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8;

import {L2Log, L2Message} from "../Storage.sol";
import "../Operations.sol";
import "../../common/interfaces/IERC20.sol";

interface IMailbox {
    struct L2CanonicalTransaction {
        uint256 txType;
        uint256 from;
        uint256 to;
        uint256 feeToken;
        uint256 ergsLimit;
        uint256 ergsPerPubdataByteLimit;
        uint256 ergsPrice;
        uint256[6] reserved;
        bytes data;
        bytes signature;
        bytes reservedDynamic;
    }

    function proveL2MessageInclusion(
        uint32 _blockNumber,
        uint256 _index,
        L2Message calldata _message,
        bytes32[] calldata _proof
    ) external view returns (bool);

    function proveL2LogInclusion(
        uint32 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) external view returns (bool);

    function serializeL2Transaction(
        uint64 _txId,
        uint256 _layer2Tip,
        address _sender,
        address _contractAddressL2,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) external pure returns (L2CanonicalTransaction memory);

    function requestL2Transaction(
        address _contractAddressL2,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps,
        QueueType _queueType
    ) external payable returns (bytes32 txHash);

    function l2TransactionBaseCost(
        uint256 _gasPrice,
        uint256 _ergsLimit,
        uint32 _calldataLength,
        QueueType _queueType
    ) external view returns (uint256);

    /// @notice New priority request event. Emitted when a request is placed into one of the queue
    event NewPriorityRequest(
        uint64 txId,
        bytes32 txHash,
        uint64 expirationBlock,
        L2CanonicalTransaction transaction,
        bytes[] factoryDeps
    );
}

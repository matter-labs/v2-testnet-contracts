pragma solidity ^0.8;

// SPDX-License-Identifier: MIT OR Apache-2.0



import {L2Log, L2Message} from "../Storage.sol";
import "../../common/interfaces/IERC20.sol";

interface IMailbox {
    struct L2CanonicalTransaction {
        uint256 txType;
        uint256 from;
        uint256 to;
        uint256 ergsLimit;
        uint256 ergsPerPubdataByteLimit;
        uint256 maxFeePerErg;
        uint256 maxPriorityFeePerErg;
        uint256 paymaster;
        uint256[6] reserved;
        bytes data;
        bytes signature;
        uint256[] factoryDeps;
        bytes paymasterInput;
        bytes reservedDynamic;
    }

    function proveL2MessageInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Message calldata _message,
        bytes32[] calldata _proof
    ) external view returns (bool);

    function proveL2LogInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) external view returns (bool);

    function serializeL2Transaction(
        uint256 _txId,
        uint256 _l2Value,
        address _sender,
        address _contractAddressL2,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) external pure returns (L2CanonicalTransaction memory);

    function requestL2Transaction(
        address _contractAddressL2,
        uint256 _l2Value,
        bytes calldata _calldata,
        uint256 _ergsLimit,
        bytes[] calldata _factoryDeps
    ) external payable returns (bytes32 txHash);

    function l2TransactionBaseCost(
        uint256 _gasPrice,
        uint256 _ergsLimit,
        uint32 _calldataLength
    ) external view returns (uint256);

    /// @notice New priority request event. Emitted when a request is placed into the priority queue
    event NewPriorityRequest(
        uint256 txId,
        bytes32 txHash,
        uint64 expirationBlock,
        L2CanonicalTransaction transaction,
        bytes[] factoryDeps
    );
}

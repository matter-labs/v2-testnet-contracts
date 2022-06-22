pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import {IMailbox, QueueType, OpTree, L2Log, L2Message} from "../../zksync/interfaces/IZkSync.sol";

/// @author Matter Labs
interface IL1Bridge {
    function deposit(
        address _l2Receiver,
        address _l1Token,
        uint256 _amount,
        QueueType _queueType
    ) external payable returns (bytes32 txHash);

    function claimFailedDeposit(
        address _depositSender,
        address _l1Token,
        bytes32 _l2TxHash,
        uint32 _l2BlockNumber,
        uint256 _l2MessageIndex,
        bytes32[] calldata _merkleProof
    ) external;

    function finalizeWithdrawal(
        uint32 _l2BlockNumber,
        uint256 _l2MessageIndex,
        bytes calldata _message,
        bytes32[] calldata _merkleProof
    ) external;

    function l2TokenAddress(address _l1Token) external view returns (address);
}

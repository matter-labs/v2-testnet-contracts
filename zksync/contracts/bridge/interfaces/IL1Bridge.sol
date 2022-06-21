// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

/// @author Matter Labs
interface IL1Bridge {
    function finalizeWithdrawal(
        uint32 _l2BlockNumber,
        uint256 _l2MessageIndex,
        bytes calldata _message,
        bytes32[] calldata _merkleProof
    ) external;
}

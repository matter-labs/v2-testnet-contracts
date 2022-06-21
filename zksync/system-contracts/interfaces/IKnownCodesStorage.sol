// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

uint256 constant MAX_KNOWN_CODE_HASHES = 16;
interface IKnownCodesStorage {
    function markAsKnownCandidates(bytes32[MAX_KNOWN_CODE_HASHES] calldata _hash) external;

    function markAsRepublished(bytes32 _hash) external;

    function removeUnusedKnownCandidate(bytes32 _hash) external;

    function checkIfKnown(bytes32 _hash) external view returns (bool);

    function getMarker(bytes32 _hash) external view returns (uint256);
}

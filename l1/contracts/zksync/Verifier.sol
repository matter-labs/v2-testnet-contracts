pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./KeysWithPlonkVerifier.sol";
import "./Config.sol";

// Hardcoded constants to avoid accessing store
contract Verifier is KeysWithPlonkVerifier, KeysWithPlonkVerifierOld {
    function verifyAggregatedBlockProof(
        uint256[] memory _recursiveInput,
        uint256[] memory _proof,
        uint8[] memory _vkIndexes,
        uint256[] memory _individual_vks_inputs,
        uint256[16] memory _subproofs_limbs
    ) external view returns (bool) {
        // HACK: ignore warnings from unused variables
        abi.encode(_recursiveInput, _proof, _vkIndexes, _individual_vks_inputs, _subproofs_limbs);
        return true;
    }
}

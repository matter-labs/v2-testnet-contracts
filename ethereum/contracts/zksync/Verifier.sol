// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

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
        // #if DUMMY_VERIFIER
        // HACK: ignore warnings from unused variables
        abi.encode(_recursiveInput, _proof, _vkIndexes, _individual_vks_inputs, _subproofs_limbs);
        return true;
        // #else
        for (uint256 i = 0; i < _individual_vks_inputs.length; ++i) {
            uint256 commitment = _individual_vks_inputs[i];
            _individual_vks_inputs[i] = commitment & INPUT_MASK;
        }
        VerificationKey memory vk = getVkAggregated(uint32(_vkIndexes.length));

        return
            verify_serialized_proof_with_recursion(
                _recursiveInput,
                _proof,
                VK_TREE_ROOT,
                VK_MAX_INDEX,
                _vkIndexes,
                _individual_vks_inputs,
                _subproofs_limbs,
                vk
            );
        // #endif
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./interfaces/IExecutor.sol";
import "./facets/Base.sol";
import "./Config.sol";

/// @author Matter Labs
contract DiamondInit is Base {
    /// @notice zkSync contract initialization
    /// @param _verifier address of Verifier contract
    /// @param _networkGovernor address who can manage the contract
    /// @param _validator address who can make blocks
    /// @param _genesisStateHash Genesis blocks (first block) state tree root hash of full tree
    /// @param _genesisZkPorterHash Genesis blocks (first block) state tree root hash of porter tree
    function initialize(
        Verifier _verifier,
        address _networkGovernor,
        address _validator,
        bytes32 _genesisStateHash,
        bytes32 _genesisZkPorterHash
    ) external {
        initializeReentrancyGuard();

        s.verifier = _verifier;
        s.networkGovernor = _networkGovernor;
        s.validators[_validator] = true;

        // We need initial state hash because it is used in the commitment of the next block
        IExecutor.StoredBlockInfo memory storedBlockZero = IExecutor.StoredBlockInfo(
            0,
            0,
            0,
            0,
            EMPTY_STRING_KECCAK,
            EMPTY_STRING_KECCAK,
            0,
            _genesisStateHash,
            _genesisZkPorterHash,
            bytes32(0)
        );

        s.storedBlockHashes[0] = keccak256(abi.encode(storedBlockZero));
    }
}

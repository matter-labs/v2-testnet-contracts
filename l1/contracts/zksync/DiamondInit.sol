pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./interfaces/IExecutor.sol";
import "./libraries/Diamond.sol";
import "./facets/Base.sol";
import "./Config.sol";

/// @author Matter Labs
/// @dev The contract is used only once to initialize the diamond proxy.
contract DiamondInit is Base {
    /// @notice zkSync contract initialization
    /// @param _verifier address of Verifier contract
    /// @param _governor address who can manage the contract
    /// @param _validator address who can make blocks
    /// @param _genesisStateHash Root hash of the full state tree observed at the genesis (initial) block
    /// @return Magic 32 bytes, which indicates that the contract logic is expected to be used as a diamond proxy initializer.
    function initialize(
        Verifier _verifier,
        address _governor,
        address _validator,
        bytes32 _genesisStateHash
    ) external reentrancyGuardInitializer returns (bytes32) {
        s.verifier = _verifier;
        s.governor = _governor;
        s.validators[_validator] = true;

        // We need to initialize the state hash because it is used in the commitment of the next block
        IExecutor.StoredBlockInfo memory storedBlockZero = IExecutor.StoredBlockInfo(
            0,
            0,
            EMPTY_STRING_KECCAK,
            DEFAULT_L2_LOGS_TREE_ROOT_HASH,
            _genesisStateHash,
            bytes32(0)
        );

        s.storedBlockHashes[0] = keccak256(abi.encode(storedBlockZero));

        return Diamond.DIAMOND_INIT_SUCCESS_RETURN_VALUE;
    }
}

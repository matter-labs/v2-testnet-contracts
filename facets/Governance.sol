pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "../interfaces/IGovernance.sol";
import "./Base.sol";
import "../libraries/Utils.sol";

/// @title Governance Contract controls access rights for contract management.
/// @author Matter Labs
contract GovernanceFacet is Base, IGovernance {
    /// @notice Change current governor
    /// @param _newGovernor Address of the new governor
    function changeGovernor(address _newGovernor) external {
        _requireGovernor(msg.sender);
        if (s.networkGovernor != _newGovernor) {
            s.networkGovernor = _newGovernor;
            emit NewGovernor(_newGovernor);
        }
    }

    /// @notice Change validator status (active or not active)
    /// @param _validator Validator address
    /// @param _active Active flag
    function setValidator(address _validator, bool _active) external {
        _requireGovernor(msg.sender);
        if (s.validators[_validator] != _active) {
            s.validators[_validator] = _active;
            emit ValidatorStatusUpdate(_validator, _active);
        }
    }
}

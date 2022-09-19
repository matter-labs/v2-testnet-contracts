pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "../interfaces/IGovernance.sol";
import "./Base.sol";

/// @title Governance Contract controls access rights for contract management.
/// @author Matter Labs
contract GovernanceFacet is Base, IGovernance {
    /// @notice Starts the transfer of governor rights. Only the current governor can propose a new pending one.
    /// @notice New governor can accept governor rights by calling `acceptGovernor` function.
    /// @param _newPendingGovernor Address of the new governor
    function setPendingGovernor(address _newPendingGovernor) external onlyGovernor {
        // Save previous value into the stack to put it into the event later
        address oldPendingGovernor = s.pendingGovernor;

        if (oldPendingGovernor != _newPendingGovernor) {
            // Change pending governor
            s.pendingGovernor = _newPendingGovernor;

            emit NewPendingGovernor(oldPendingGovernor, _newPendingGovernor);
        }
    }

    /// @notice Accepts transfer of admin rights. Only pending governor can accept the role.
    function acceptGovernor() external {
        address pendingGovernor = s.pendingGovernor;
        require(msg.sender == pendingGovernor, "n4"); // Only proposed by current governor address can claim the governor rights

        if (pendingGovernor != s.governor) {
            s.governor = pendingGovernor;
            s.pendingGovernor = address(0);

            emit NewPendingGovernor(pendingGovernor, address(0));
            emit NewGovernor(pendingGovernor);
        }
    }

    /// @notice Change validator status (active or not active)
    /// @param _validator Validator address
    /// @param _active Active flag
    function setValidator(address _validator, bool _active) external onlyGovernor {
        if (s.validators[_validator] != _active) {
            s.validators[_validator] = _active;
            emit ValidatorStatusUpdate(_validator, _active);
        }
    }
}

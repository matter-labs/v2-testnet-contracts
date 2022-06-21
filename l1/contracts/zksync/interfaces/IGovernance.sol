// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8;

interface IGovernance {
    function changeGovernor(address _newGovernor) external;

    function setValidator(address _validator, bool _active) external;

    /// @notice Validator's status changed
    event ValidatorStatusUpdate(address indexed validatorAddress, bool isActive);

    /// @notice Governor changed
    event NewGovernor(address newGovernor);
}

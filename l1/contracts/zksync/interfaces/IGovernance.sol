pragma solidity ^0.8;

// SPDX-License-Identifier: MIT OR Apache-2.0



interface IGovernance {
    function setPendingGovernor(address _newPendingGovernor) external;

    function acceptGovernor() external;

    function setValidator(address _validator, bool _active) external;

    /// @notice Validator's status changed
    event ValidatorStatusUpdate(address indexed validatorAddress, bool isActive);

    /// @notice pendingGovernor is changed
    /// @dev Also emitted when new governor is accepted and in this case, `newPendingGovernor` would be zero address
    event NewPendingGovernor(address indexed oldPendingGovernor, address indexed newPendingGovernor);

    /// @notice Governor changed
    event NewGovernor(address indexed newGovernor);
}

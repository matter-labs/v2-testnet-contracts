pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../Storage.sol";
import "../ReentrancyGuard.sol";

/// @title Base contract containing functions accessible to the other facets.
/// @author Matter Labs
contract Base is ReentrancyGuard {
    AppStorage internal s;

    /// @notice Checks if validator is active
    /// @param _address Validator address
    function _requireActiveValidator(address _address) internal view {
        require(s.validators[_address], "1h"); // validator is not active
    }

    /// @notice Check if specified address is is governor
    /// @param _address Address to check
    function _isGovernor(address _address) internal view returns (bool) {
        return _address == s.networkGovernor;
    }

    /// @notice Check if specified address is a governor
    /// @param _address Address to check
    function _requireGovernor(address _address) internal view {
        require(_address == s.networkGovernor, "1g"); // only by governor
    }
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

interface INonceHolder {
    function getAccountNonce() external view returns (uint256);

    function incrementNonce() external returns (uint256);

    function incrementNonceIfEquals(uint256 _expectedNonce) external;

    function getDeploymentNonce(address _address) external view returns (uint256);

    function incrementDeploymentNonce(address _address) external returns (uint256);
}

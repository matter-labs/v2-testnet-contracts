// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

/**
 * @author Matter Labs
 * @notice Contracts that store chain Id of the network.
 * @notice Used as a temporary solution to be a source of the truth about the chain id of the network.
 */
contract ChainIdSimulator {
    uint256 public chainId = 270;
}

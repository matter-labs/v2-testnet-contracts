pragma solidity ^0.8;

// SPDX-License-Identifier: MIT OR Apache-2.0



interface IGetters {
    function getVerifier() external view returns (address);

    function getGovernor() external view returns (address);

    function getPendingBalance(address _address, address _token) external view returns (uint256);

    function getTotalBlocksCommitted() external view returns (uint32);

    function getTotalBlocksVerified() external view returns (uint32);

    function getTotalBlocksExecuted() external view returns (uint32);

    function getTotalPriorityRequests() external view returns (uint64);

    function isValidator(address _address) external view returns (bool);
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./Base.sol";
import "../interfaces/IGetters.sol";

/// @title Getters Contract implements functions for getting contract state from outside the blockchain.
/// @author Matter Labs
contract GettersFacet is Base, IGetters {
    function getVerifier() external view returns (address) {
        return address(s.verifier);
    }

    function getGovernor() external view returns (address) {
        return address(s.networkGovernor);
    }

    function getPendingBalance(address _address, address _token) external view returns (uint256) {
        return s.pendingBalances[_address][_token];
    }

    function getTotalBlocksCommitted() external view returns (uint32) {
        return s.totalBlocksCommitted;
    }

    function getTotalBlocksVerified() external view returns (uint32) {
        return s.totalBlocksVerified;
    }

    function getTotalBlocksExecuted() external view returns (uint32) {
        return s.totalBlocksExecuted;
    }

    function getTotalPriorityRequests() external view returns (uint64) {
        return s.totalPriorityRequests;
    }

    function isValidator(address _address) external view returns (bool) {
        return s.validators[_address];
    }
}

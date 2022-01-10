pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED



import "../../facets/Executor.sol";
import "../../facets/Getters.sol";

contract WithdrawalTest is ExecutorFacet, GettersFacet {
    function withdrawOrStore(
        address _zkSyncTokenAddress,
        address _recipient,
        uint256 _amount
    ) external {
        return _withdrawOrStore(_zkSyncTokenAddress, _recipient, _amount);
    }
}

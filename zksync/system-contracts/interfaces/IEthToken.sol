// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

interface IEthToken {
    function balanceOf(address) external returns (uint256);
    
    function transferFromTo(address _from, address _to, uint256 _amount) external;
}

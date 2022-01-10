pragma solidity ^0.8;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./IBridge.sol";
import "./IGovernance.sol";
import "./IPriorityMode.sol";
import "./IExecutor.sol";
import "./IDiamondCut.sol";
import "./IGetters.sol";

interface IZkSync is IBridge, IGovernance, IPriorityMode, IExecutor, IDiamondCut, IGetters {}

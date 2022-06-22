pragma solidity ^0.8;

// SPDX-License-Identifier: MIT OR Apache-2.0



import {IMailbox} from "./IMailbox.sol";
import "./IGovernance.sol";
import "./IPriorityMode.sol";
import "./IExecutor.sol";
import "./IDiamondCut.sol";
import "./IGetters.sol";

interface IZkSync is IMailbox, IGovernance, IPriorityMode, IExecutor, IDiamondCut, IGetters {}

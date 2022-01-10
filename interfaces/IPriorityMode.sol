pragma solidity ^0.8;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../libraries/Operations.sol";
import "../libraries/PriorityModeLib.sol";

interface IPriorityMode {
    function activatePriorityMode(uint32 _ethExpirationBlock) external returns (bool);

    function placeBidForBlocksProcessingAuction(uint112 _complexityRoot, Operations.OpTree _opTree) external payable;

    function updatePriorityModeSubEpoch() external;

    /// @notice Priority mode entered event
    event PriorityModeActivated();

    /// @notice New max priority mode auction bid.
    event NewPriorityModeAuctionBid(Operations.OpTree opTree, address sender, uint96 bidAmount, uint256 complexity);

    /// @notice Switch priority mode sub-epoch event.
    event NewPriorityModeSubEpoch(PriorityModeLib.Epoch subEpoch, uint128 subEpochEndTimestamp);
}

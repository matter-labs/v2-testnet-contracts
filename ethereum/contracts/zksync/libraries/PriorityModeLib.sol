// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "../libraries/CheckpointedPrefixSum.sol";
import "../libraries/PriorityQueue.sol";
import "../Operations.sol";
import "../libraries/Auction.sol";
import "../libraries/Utils.sol";

import "../Storage.sol";

library PriorityModeLib {
    using CheckpointedPrefixSum for CheckpointedPrefixSum.PrefixSum;
    using PriorityQueue for PriorityQueue.Queue;
    using PriorityModeLib for Epoch;

    /// @notice Switch priority mode sub-epoch event.
    event NewPriorityModeSubEpoch(PriorityModeLib.Epoch subEpoch, uint128 subEpochEndTimestamp);

    enum Epoch {
        CommonAuction,
        CommonProcessing,
        RollupAuction,
        RollupProcessing,
        Delay
    }

    struct State {
        bool priorityModeEnabled;
        Epoch epoch;
        uint128 subEpochEndTimestamp;
        uint32 lastProcessedComplexityCheckpointID;
    }

    /// @notice Changes the current sub-epoch to the new one if needed
    /// NOTE: require enabled priority mode
    function updateEpoch(AppStorage storage s) internal {
        State memory state = s.priorityModeState;

        require(state.priorityModeEnabled, "j"); // priority mode should be activated

        // If the sub-epoch is not over yet, then nothing needs to be updated
        if (block.timestamp <= state.subEpochEndTimestamp) {
            return;
        }

        Epoch newSubEpoch = state.epoch;

        if (state.epoch == Epoch.Delay) {
            newSubEpoch = Epoch.CommonAuction;
        } else if (state.epoch == Epoch.CommonAuction) {
            // If at least someone made a bet, then go to the processing mode otherwise, go to the rollup auction
            newSubEpoch = s.currentMaxAuctionBid.bidAmount != 0 ? Epoch.CommonProcessing : Epoch.RollupAuction;
        } else if (state.epoch == Epoch.RollupAuction) {
            // If at least someone made a bet, then go to the processing mode otherwise, go to the delay sub-epoch
            newSubEpoch = s.currentMaxAuctionBid.bidAmount != 0 ? Epoch.RollupProcessing : Epoch.Delay;
        } else {
            // Here are considered `CommonProcessing` and `RollupProcessing`.

            // All blocks that have not been executed must be reverted
            // so that the next executors can commit, verify and execute their blocks.
            Utils.revertBlocks(s, 0);

            bool auctionProcessSuccessful = _isAuctionProcessSuccessful(s, state);

            // It is necessary to replace the bid after processing operations so that the owner of the bid
            // can't win the auction twice with the same bid, or receive pledge twice.
            // Return funds for the auction winner only if the the executor fulfilled the conditions of the auction.
            Auction.replaceBid(s, Auction.Bid(address(0), 0, 0), auctionProcessSuccessful);

            // `RollupAuction` should be activated only if we have unsuccessfully finished common processing sub-epoch.
            if (state.epoch == Epoch.CommonProcessing && !auctionProcessSuccessful) {
                newSubEpoch = Epoch.RollupAuction;
            } else {
                // If the processing completed successfully or the current sub-epoch is rollup operations processing, then we
                // should give the opportunity to move the priority operations from the heap buffer to the main heap in delay sub-epoch.
                newSubEpoch = Epoch.Delay;
            }
        }

        if (newSubEpoch != s.priorityModeState.epoch) {
            setNewPriorityModeState(s, newSubEpoch);
        }
    }

    /// @dev Returns whether the epoch of processing operations after the auction was successful
    /// @dev Returns True if and only if:
    /// @dev 1. sub-epoch that corresponds to the given priority mode state is under the
    /// @dev common or rollup sub-epoch of processing priority operations
    /// @dev 2. processed complexity from the start of current sub-epoch is not less to the value that the executor
    /// @dev committed at the auction OR there are no priority operations that were expired.
    function _isAuctionProcessSuccessful(AppStorage storage s, State memory _state) private view returns (bool) {
        bool currentSubEpochIsAuction = false;
        bool allOperationsPerfomed = false;

        if (_state.epoch == Epoch.CommonProcessing) {
            // To consider that all priority operations were processed in Commom mode
            // it is necessary that all required priority operations have been processed from both queues
            allOperationsPerfomed =
                _allPriorityOpsPerformed(s, OpTree.Full) &&
                _allPriorityOpsPerformed(s, OpTree.Rollup);
            currentSubEpochIsAuction = true;
        } else if (_state.epoch == Epoch.RollupProcessing) {
            // In the case of a rollup queue, only operations from rollup priority queues should be processed
            allOperationsPerfomed = _allPriorityOpsPerformed(s, OpTree.Rollup);
            currentSubEpochIsAuction = true;
        }

        // Check how much complexity was actually processed from the moment of the previous sub-epoch
        uint256 checkpointID = _state.lastProcessedComplexityCheckpointID;
        uint256 totalProcessedComplexity = s.processedComplexityHistory.totalSumFromCheckpointID(checkpointID);

        uint256 expectedRootComplexity = uint256(s.currentMaxAuctionBid.complexityRoot);
        // It is safe to multiply because the maximum value `expectedRootComplexity` is `type(uint128).max`
        uint256 expectedComplexity;
        unchecked {
            expectedComplexity = expectedRootComplexity * expectedRootComplexity;
        }

        return currentSubEpochIsAuction && (allOperationsPerfomed || totalProcessedComplexity >= expectedComplexity);
    }

    /// @notice Checks that all priority operations that should be performed during processing sub-epoch have been performed
    /// @param _opTree Type of priority op processing queue, for which the check will be performed
    function _allPriorityOpsPerformed(AppStorage storage s, OpTree _opTree) private view returns (bool) {
        // Heap is immutable during the processing sub-epoch, so the operator has the ability to process
        // all the priority operations from the heap. Therefore, if there is at least one priority operation
        // in the heap, then not all priority operations that could be processed have been processed and vice versa.
        bool heapIsProcesssed = s.priorityQueue[_opTree].heapSize() == 0;

        // Deque is always mutable, but all new priority operations pushed the end of this structure,
        // so it is enough to determine whether there are priority operations in the deque
        // that could be processed during the processing period or not.
        bool dequeIsProcesssed = !dequeOpsExpired(s, _opTree);

        return heapIsProcesssed && dequeIsProcesssed;
    }

    /// @notice Сhecks that there are priority operations from deque that have expired
    /// @param _opTree Type of priority op processing queue, for which the check will be performed
    function dequeOpsExpired(AppStorage storage s, OpTree _opTree) internal view returns (bool) {
        // If deque is empty then there are no priority operations whose processing time has expired
        if (s.priorityQueue[_opTree].dequeSize() == 0) {
            return false;
        }

        // Priority operations are always appended to the end of the deque,
        // so the oldest operation is in front of the structure
        uint64 frontOpId = s.priorityQueue[_opTree].frontDequeOperationID();
        PriorityOperation memory frontOp = s.storedOperations.inner[frontOpId];

        // Check that the processing deadline for the oldest priority operation has expired
        return block.number > frontOp.expirationBlock;
    }

    /// @notice Changes the current priority mode state
    /// @param _newSubEpoch sub-epoch, which should be listed as a new
    function setNewPriorityModeState(AppStorage storage s, Epoch _newSubEpoch) internal {
        // Different sub-epochs have different durations, so deduce the duration of the epoch to which we want to switch
        uint128 subEpochDuration;
        if (_newSubEpoch.isAuction()) {
            subEpochDuration = PRIORITY_MODE_AUCTION_TIME;
        } else if (_newSubEpoch.isProcessing()) {
            subEpochDuration = PRIORITY_MODE_ACTION_WINNER_PROVING_TIME;
        } else {
            subEpochDuration = PRIORITY_MODE_DELAY_SUBEPOCH_TIME;
        }

        uint128 subEpochEndTimestamp = uint128(block.timestamp) + subEpochDuration;

        // Save the last added checkpoint ID of processed complexity history,
        // in order to later determine how much complexity was processed during the sub-epoch
        uint256 lastCheckpointID = s.processedComplexityHistory.lastCheckpointID;

        s.priorityModeState = State(true, _newSubEpoch, subEpochEndTimestamp, uint32(lastCheckpointID));

        emit NewPriorityModeSubEpoch(_newSubEpoch, subEpochEndTimestamp);
    }

    /// @notice Checks that given sub-epoch is common/rollup auction sub-epoch
    function isAuction(Epoch _epoch) internal pure returns (bool) {
        return _epoch == Epoch.CommonAuction || _epoch == Epoch.RollupAuction;
    }

    /// @notice Checks that given sub-epoch is common/rollup processing sub-epoch
    function isProcessing(Epoch _epoch) internal pure returns (bool) {
        return _epoch == Epoch.CommonProcessing || _epoch == Epoch.RollupProcessing;
    }
}

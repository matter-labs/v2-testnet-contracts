pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../interfaces/IERC20.sol";
import "../interfaces/IPriorityMode.sol";

import "../libraries/Utils.sol";
import "../libraries/Operations.sol";
import "../libraries/PriorityQueue.sol";
import "../libraries/PriorityModeLib.sol";
import "../libraries/Auction.sol";
import "../libraries/CheckpointedPrefixSum.sol";

import "./Base.sol";

/// @title PriorityMode Contract manages processes during the priority mode.
/// @author Matter Labs
contract PriorityModeFacet is Base, IPriorityMode {
    using Auction for Auction.Bid;
    using PriorityQueue for PriorityQueue.Queue;
    using CheckpointedPrefixSum for CheckpointedPrefixSum.PrefixSum;

    /// @notice Checks if Priority mode can be entered. If true - enters priority mode and emits PriorityMode event.
    /// @dev Priority mode must be entered in case of:
    /// 1. The time for moving operations from the buffer heap to the main heap is expired and
    /// total gas used for moving priority operations is less than `EXPECTED_GAS_SPENT_FOR_MOVING`.
    /// 2. The time for processing operations from an array or heap has been expired and
    /// complexity of processed priority operations is less than `EXPECTED_PROCESSED_COMPLEXITY`.
    /// @param _ethExpirationBlock Ethereum block number up to which heap priority operation should have been performed
    /// @return bool flag that is true if the Priority mode must be entered.
    function activatePriorityMode(uint32 _ethExpirationBlock) external nonReentrant returns (bool) {
        return false;
    }

    /// @notice Place a bid in a block processing auction
    /// @param _complexityRoot square root of the number of promised processed priority operations complexity
    /// @param _opTree Type of priority op processing queue, for which the bid is being placed
    /// NOTE: If the new bid is not the most significant, then the transaction will be failed
    /// NOTE: winning bid can be burned if creator does not process blocks for the complexity
    /// as he committed `PRIORITY_MODE_ACTION_WINNER_PROVING_TIME` seconds after the auction.
    function placeBidForBlocksProcessingAuction(uint112 _complexityRoot, Operations.OpTree _opTree)
        external
        payable
        nonReentrant
    {
        revert("t1"); // this functionality is disabled on testnet
    }

    /// @notice Changes the current sub-epoch to the new one if needed
    /// NOTE: Modifier of this method is not `public` because the internal version of this method -
    /// `_updatePriorityModeSubEpoch` is used when inheriting in the main and additional zkSync contract.
    function updatePriorityModeSubEpoch() external nonReentrant {
        revert("t2"); // this functionality is disabled on testnet
    }

    /// @notice Checks that there are no priority operations from buffer heap that have expired
    /// or sufficient gas has been spent on moving priority operations.
    /// @param _ethExpirationBlock Ethereum block number up to which buffer heap priority operation should have been performed
    function _bufferProcessingConditionFulfilled(uint32 _ethExpirationBlock) internal view returns (bool) {
        // To find out how much gas was spent on moving priority operations in the last `PRIORITY_BUFFER_EXPIRATION`,
        // we will find out how much gas was spent during the period [block.number - PRIORITY_BUFFER_EXPIRATION, block.number]
        uint256 fromEthBlock = block.number - PRIORITY_BUFFER_EXPIRATION;
        uint224 gasUsedToMoveOperations = s.movementOperationsGasUsage.totalSumFromEthBlock(fromEthBlock);

        // If the amount of gas spent is greater or equal than operators should process for
        // `PRIORITY_BUFFER_EXPIRATION` blocks, then conditions are fulfilled.
        if (gasUsedToMoveOperations >= EXPECTED_GAS_SPENT_FOR_MOVING) {
            return true;
        }

        // Сheck that the block number is less than the current one
        // and the priority operation that expired is actually in the buffer heap.
        bool heapBufferExpiredOperationsExists = block.number > _ethExpirationBlock &&
            s.expiringOpsCounter.bufferHeap[_ethExpirationBlock] > 0;

        return !heapBufferExpiredOperationsExists;
    }

    /// @notice Checks that there are no priority operations from the main heap and deque that have expired
    /// or sufficient complexity has been processed.
    /// @param _ethExpirationBlock Ethereum block number up to which heap priority operation should have been performed
    function _mainQueueProcessingConditionFulfilled(uint32 _ethExpirationBlock) internal view returns (bool) {
        // To find out how much complexity was processed in the last `PRIORITY_EXPIRATION`,
        // we will find out how much gas was spent during the period [block.number - PRIORITY_EXPIRATION, block.number]
        uint256 fromEthBlock = block.number - PRIORITY_EXPIRATION;
        uint224 totalProcessedCompexity = s.processedComplexityHistory.totalSumFromEthBlock(fromEthBlock);

        // If the processed complexity is greater or equal than operators should process for
        // `PRIORITY_EXPIRATION` blocks, then conditions are fulfilled.
        if (totalProcessedCompexity >= EXPECTED_PROCESSED_COMPLEXITY) {
            return true;
        }

        /// Check that exists expired priority operations from one of the deques.
        bool dequesOperationsExpired = PriorityModeLib.dequeOpsExpired(s, Operations.OpTree.Full) ||
            PriorityModeLib.dequeOpsExpired(s, Operations.OpTree.Rollup);

        // Сheck that the block number is less than the current one
        // and the priority operation that expired is actually in the heap.
        bool heapsExpiredOperationsExists = block.number > _ethExpirationBlock &&
            s.expiringOpsCounter.heap[_ethExpirationBlock] > 0;

        return !dequesOperationsExpired && !heapsExpiredOperationsExists;
    }
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

/// @author Matter Labs
library CheckpointedPrefixSum {
    /// @notice A checkpoint for marking accumulated sum for a given block
    /// @param ethBlock Ethereum block number at which the checkpoint was created (not a unique identifier)
    /// @param accumulatedSum Accumulated sum at the time of checkpoint
    /// NOTE: Size types are chosen in such a way that all members of the structure occupy 1 slot
    struct Checkpoint {
        uint32 ethBlock;
        uint224 accumulatedSum;
    }

    /// @notice storing accumulated sum for values by ID and Ethereum block
    /// @param checkpoints A record of accumulated sum and Eth block checkpoints by index
    /// @param lastCheckpointID shows the last added checkpoint ID
    /// NOTE: It is considered that `PrefixSum.checkpoints[0]` is already stored in the structure.
    /// Therefore, indexing for new checkpoints will start from one.
    struct PrefixSum {
        mapping(uint256 => Checkpoint) checkpoints;
        uint256 lastCheckpointID;
    }

    /// @notice Adds a checkpoint with given value and the current Ethereum block number
    function pushCheckpointWithCurrentBlockNumber(PrefixSum storage _self, uint224 _value) internal {
        uint256 lastCheckpointID = _self.lastCheckpointID;

        Checkpoint memory lastCheckpoint = _self.checkpoints[lastCheckpointID];
        Checkpoint memory newCheckpoint = Checkpoint(uint32(block.number), lastCheckpoint.accumulatedSum + _value);

        _self.checkpoints[lastCheckpointID + 1] = newCheckpoint;
        _self.lastCheckpointID += 1;
    }

    /// @notice Searches for the sum of all values that have been written to the structure
    /// @notice since the beginning of the given Ethereum block number, inсlusive
    function totalSumFromEthBlock(PrefixSum storage _self, uint256 _fromEthBlock) internal view returns (uint224) {
        uint256 lastCheckpointID = _self.lastCheckpointID;

        uint256 low = 0;
        uint256 high = lastCheckpointID;

        while (low < high) {
            uint256 mid = high - (high - low) / 2;
            Checkpoint memory cp = _self.checkpoints[mid];
            if (cp.ethBlock >= _fromEthBlock) {
                high = mid - 1;
            } else {
                low = mid;
            }
        }

        return _self.checkpoints[lastCheckpointID].accumulatedSum - _self.checkpoints[low].accumulatedSum;
    }

    /// @notice Searches for the sum of all values that have been written to the structure
    /// @notice since adding a checkpoint with the given id, exclusive
    function totalSumFromCheckpointID(PrefixSum storage _self, uint256 _fromCheckpointID)
        internal
        view
        returns (uint224)
    {
        return
            _self.checkpoints[_self.lastCheckpointID].accumulatedSum -
            _self.checkpoints[_fromCheckpointID].accumulatedSum;
    }

    // #if DUMMY_PREFIX_SUM_LIB

    /// @dev Adds a checkpoint with given Ethereum block number and value
    /// NOTE: USE FOR TESTING ONLY
    function DUMMY_pushCheckpoint(
        PrefixSum storage _self,
        uint32 _ethBlock,
        uint224 _value
    ) internal {
        uint256 lastCheckpointID = _self.lastCheckpointID;

        Checkpoint memory lastCheckpoint = _self.checkpoints[lastCheckpointID];
        Checkpoint memory newCheckpoint = Checkpoint(_ethBlock, lastCheckpoint.accumulatedSum + _value);

        _self.checkpoints[lastCheckpointID + 1] = newCheckpoint;
        _self.lastCheckpointID += 1;
    }

    // #endif
}

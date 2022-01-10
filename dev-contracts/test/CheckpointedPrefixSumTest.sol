pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED



import "../../libraries/CheckpointedPrefixSum.sol";

contract CheckpointedPrefixSumTest {
    using CheckpointedPrefixSum for CheckpointedPrefixSum.PrefixSum;

    CheckpointedPrefixSum.PrefixSum internal prefixSum;

    /// @dev Values for adding a new checkpoint in checkpointed prefix sum
    /// NOTE: used for testing only
    struct DummyCheckpointInfo {
        uint32 ethBlock;
        uint224 value;
    }

    function pushCheckpoints(uint224[] calldata _values) external {
        for (uint256 i = 0; i < _values.length; ++i) {
            prefixSum.pushCheckpointWithCurrentBlockNumber(_values[i]);
        }
    }

    function pushOneCheckpoint(uint224 _value) external {
        prefixSum.pushCheckpointWithCurrentBlockNumber(_value);
    }


    function totalSumFromEthBlock(uint32 _fromEthBlock) external view returns (uint224) {
        return prefixSum.totalSumFromEthBlock(_fromEthBlock);
    }

    function totalSumFromCheckpointID(uint256 _fromCheckpointID) external view returns (uint224) {
        return prefixSum.totalSumFromCheckpointID(_fromCheckpointID);
    }
}

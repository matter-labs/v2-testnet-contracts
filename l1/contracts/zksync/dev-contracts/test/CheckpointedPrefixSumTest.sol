// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

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

    // #if DUMMY_PREFIX_SUM_LIB

    function DUMMY_pushOneCheckpoint(uint32 _ethBlock, uint224 _value) external {
        prefixSum.DUMMY_pushCheckpoint(_ethBlock, _value);
    }

    function DUMMY_pushCheckpoints(DummyCheckpointInfo[] calldata _dummyCheckpointInfo) external {
        for (uint256 i = 0; i < _dummyCheckpointInfo.length; ++i) {
            prefixSum.DUMMY_pushCheckpoint(_dummyCheckpointInfo[i].ethBlock, _dummyCheckpointInfo[i].value);
        }
    }

    // #endif

    function totalSumFromEthBlock(uint32 _fromEthBlock) external view returns (uint224) {
        return prefixSum.totalSumFromEthBlock(_fromEthBlock);
    }

    function totalSumFromCheckpointID(uint256 _fromCheckpointID) external view returns (uint224) {
        return prefixSum.totalSumFromCheckpointID(_fromCheckpointID);
    }
}

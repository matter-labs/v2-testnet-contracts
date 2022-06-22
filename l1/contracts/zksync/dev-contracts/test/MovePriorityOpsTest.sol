pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED



import "../../Operations.sol";
import "../../facets/Executor.sol";
import "./DummyPriorityQueue.sol";

contract MovePriorityOpsTest is ExecutorFacet, DummyPriorityQueue {
    /// @dev external version of `_moveOnePriorityOpFromBufferToMainHeap`
    function moveOnePriorityOpFromBufferToMainHeap(OpTree _opTree, uint32 _newExpirationBlock)
        external
        returns (uint64)
    {
        return _moveOnePriorityOpFromBufferToMainHeap(_opTree, _newExpirationBlock);
    }

    /// @dev external version of `_movePriorityOps`
    function movePriorityOps(
        uint256 _nOpsToMove,
        OpTree _opTree,
        uint32 _newExpirationBlock
    ) external returns (uint256, uint64[] memory) {
        return _movePriorityOps(_nOpsToMove, _opTree, _newExpirationBlock);
    }
}

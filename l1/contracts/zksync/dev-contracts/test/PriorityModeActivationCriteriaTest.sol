// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "../../facets/PriorityMode.sol";
import "./DummyPriorityQueue.sol";

contract PriorityModeActivationCriteriaTest is PriorityModeFacet, DummyPriorityQueue {
    constructor() {
        initializeReentrancyGuard();
    }

    /// @notice external version of `_bufferProcessingConditionFulfilled`
    function bufferProcessingConditionFulfilled(uint32 _ethExpirationBlock) external view returns (bool) {
        return _bufferProcessingConditionFulfilled(_ethExpirationBlock);
    }

    /// @notice external version of `_mainQueueProcessingConditionFulfilled`
    function mainQueueProcessingConditionFulfilled(uint32 _ethExpirationBlock) external view returns (bool) {
        return _mainQueueProcessingConditionFulfilled(_ethExpirationBlock);
    }
}

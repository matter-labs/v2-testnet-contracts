pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../interfaces/IZkSync.sol";

contract FailOnReceive {
    receive() external payable {
        revert();
    }

    function placeBid(
        IZkSync zksync,
        uint112 complexityRoot,
        OpTree opTree
    ) external payable {
        zksync.placeBidForBlocksProcessingAuction{value: msg.value}(complexityRoot, opTree);
    }
}

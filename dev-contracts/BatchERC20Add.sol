pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED


import "../libraries/Operations.sol";

import "../interfaces/IERC20.sol";
import "../interfaces/IZkSync.sol";

/// Adds multiple ERC20 tokens to governance at once
contract BatchERC20Add {
    constructor(IZkSync _zkSync, address[] memory _tokens) payable {
        uint256 addTokenCost = _zkSync.addTokenBaseCost(
            tx.gasprice,
            Operations.QueueType.Deque,
            Operations.OpTree.Full
        );

        require(msg.value >= addTokenCost * _tokens.length);
        for (uint256 i = 0; i < _tokens.length; ++i) {
            _zkSync.addToken{value: addTokenCost}(
                IERC20(_tokens[i]),
                Operations.QueueType.Deque,
                Operations.OpTree.Full
            );
        }
        selfdestruct(payable(msg.sender));
    }
}

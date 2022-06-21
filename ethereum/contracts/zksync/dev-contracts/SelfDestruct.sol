// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

contract SelfDestruct {
    function destroy(address payable to) external {
        selfdestruct(to);
    }

    // Need this to send some funds to the contract
    receive() external payable {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IPaymaster.sol";
import "./interfaces/IPaymasterFlow.sol";
import "./interfaces/IERC20.sol";
import "./TransactionHelper.sol";

// This is a dummy paymaster. It expects the paymasterInput to contain its "signature" as well as the needed exchange rate.
// It supports only approval-based paymaster flow.
contract TestnetPaymaster is IPaymaster {
    function validateAndPayForPaymasterTransaction(Transaction calldata _transaction)
        external
        payable
        returns (bytes memory context)
    {
        require(msg.sender == BOOTLOADER_ADDRESS, "Only bootloader can call this contract");
        require(_transaction.paymasterInput.length >= 4, "The standard paymaster input must be at least 4 bytes long");

        bytes4 paymasterInputSelector = bytes4(_transaction.paymasterInput[0:4]);
        if (paymasterInputSelector == IPaymasterFlow.approvalBased.selector) {
            // While the actual data consists of address, uint256 and bytes data,
            // the data is not needed for the testnet paymaster
            (address token, uint256 amount, ) = abi.decode(_transaction.paymasterInput[4:], (address, uint256, bytes));

            // Firstly, we verify that the user has provided enough allowance
            address userAddress = address(uint160(_transaction.from));
            address thisAddress = address(this);

            uint256 providedAllowance = IERC20(token).allowance(userAddress, thisAddress);
            require(providedAllowance >= amount, "The user did not provide enough allowance");

            // The testnet paymaster exchanges X wei of the token to the X wei of ETH.
            uint256 requiredETH = _transaction.ergsLimit * _transaction.maxFeePerErg;
            require(amount >= requiredETH, "User does not provide enough tokens to exchange");

            // Pulling all the tokens from the user
            IERC20(token).transferFrom(userAddress, thisAddress, amount);
            // The bootloader never returns any data, so it can safely be ignored here.
            (bool success, ) = payable(BOOTLOADER_ADDRESS).call{value: requiredETH}("");
            require(success, "Failed to transfer funds to the bootloader");
        } else {
            revert("Unsupported paymaster flow");
        }
    }

    function postOp(
        bytes calldata _context,
        Transaction calldata _transaction,
        ExecutionResult _txResult,
        uint256 _maxRefundedErgs
    ) external payable override {
        // Refunds are not supported yet.
    }

    receive() external payable {}
}

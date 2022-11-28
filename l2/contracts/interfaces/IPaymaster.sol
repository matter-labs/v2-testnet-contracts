pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../L2ContractHelper.sol";

enum ExecutionResult {
    Revert,
    Success
}

interface IPaymaster {
    function validateAndPayForPaymasterTransaction(
        bytes32 _txHash,
        bytes32 _suggestedSignedHash,
        Transaction calldata _transaction
    ) external payable returns (bytes memory context);

    /// @dev Called by the bootloader after the execution of the transaction. Please note that
    /// there is no guarantee that this method will be called at all. Unlike the original EIP4337,
    /// this method won't be called if the transaction execution results in out-of-gas.
    /// @param _context, the context of the execution, returned by the "validateAndPayForPaymasterTransaction" method.
    /// @param  _transaction, the users' transaction.
    /// @param _txResult, the result of the transaction execution (success or failure).
    /// @param _maxRefundedErgs, the upper bound on the amout of ergs that could be refunded to the paymaster.
    /// @dev The exact amount refunded depends on the ergs spent by the "postOp" itself and so the developers should
    /// take that into account.
    function postOp(
        bytes calldata _context,
        Transaction calldata _transaction,
        bytes32 _txHash,
        bytes32 _suggestedSignedHash,
        ExecutionResult _txResult,
        uint256 _maxRefundedErgs
    ) external payable;
}

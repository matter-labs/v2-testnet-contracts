pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED



import "../../libraries/Operations.sol";

contract OperationsTest {
    function testWithdrawOpData(Operations.Withdraw memory _example, bytes memory _opData) external pure {
        (, Operations.Withdraw memory parsed) = Operations.readWithdrawOpData(_opData, 0);
        require(_example.zkSyncTokenAddress == parsed.zkSyncTokenAddress, "tok");
        require(_example.amount == parsed.amount, "amn");
        require(_example.to == parsed.to, "to");
    }

    function testDepositPriorityQueue(Operations.Deposit memory _example, bytes memory _opData) external pure {
        bytes memory result = Operations.writeDepositOpDataForPriorityQueue(_example);
        require(keccak256(result) == keccak256(_opData));
    }

    function testAddTokenPriorityQueue(Operations.AddToken memory _example, bytes memory _opData) external pure {
        bytes memory result = Operations.writeAddTokenOpDataForPriorityQueue(_example);
        require(keccak256(result) == keccak256(_opData));
    }

    function testWithdrawPriorityQueue(Operations.Withdraw memory _example, bytes memory _opData) external pure {
        bytes memory result = Operations.writeWithdrawOpDataForPriorityQueue(_example);
        require(keccak256(result) == keccak256(_opData));
    }

    function testDeployContractPriorityQueue(Operations.DeployContract memory _example, bytes memory _opData)
        external
        pure
    {
        bytes memory result = Operations.writeDeployContractOpDataForPriorityQueue(_example);
        require(keccak256(result) == keccak256(_opData));
    }

    function testExecutePriorityQueue(Operations.Execute memory _example, bytes memory _opData) external pure {
        bytes memory result = Operations.writeExecuteOpDataForPriorityQueue(_example);
        require(keccak256(result) == keccak256(_opData));
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../libraries/Bytes.sol";
import "../libraries/Utils.sol";

/// @title zkSync operations tools
library Operations {
    /// @notice Priority Operation container
    /// @param hashedCircuitOpData Hashed priority operation data that is needed to process the operation
    /// @param expirationBlock Expiration block number (ETH block) for this request (must be satisfied before)
    /// @param layer2Tip Additional payment to the operator as an incentive to perform the operation
    struct PriorityOperation {
        bytes16 hashedCircuitOpData;
        uint32 expirationBlock;
        uint96 layer2Tip;
    }

    /// @notice A structure that stores all priority operations by ID
    /// used for easy acceptance as an argument in functions
    struct StoredOperations {
        mapping(uint64 => PriorityOperation) inner;
    }

    /// @notice zkSync operation type
    enum OpType {
        Deposit,
        AddToken,
        Withdraw,
        DeployContract,
        Execute
    }

    /// @notice Indicator that the operation can interact with Rollup and Porter trees, or only with Rollup
    enum OpTree {
        Full,
        Rollup
    }

    /// @notice Priority operations queue type
    enum QueueType {
        Deque,
        HeapBuffer,
        Heap
    }

    // Byte lengths
    uint8 constant OP_TYPE_BYTES = 1;

    // Deposit opdata
    struct Deposit {
        // uint8 opType; -- present in opdata, ignored at serialization
        address zkSyncTokenAddress;
        uint256 amount;
        address owner;
    }

    /// Serialize deposit opdata
    function writeDepositOpDataForPriorityQueue(Deposit memory op) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(uint8(OpType.Deposit), op.zkSyncTokenAddress, op.amount, op.owner);
    }

    // AddToken opdata
    // `encodePacked` packs dynamic `bytes` type without length, so we have to include lengths
    // of the bytes fields.
    // Very likely that it's possible not to include the nameLength as it is possible to derive it
    // from the length of the pubdata, but it would complicate the process of L1 decoding of pubdata
    // it is fine for now
    struct AddToken {
        // uint8 opType; -- present in opdata, ignored at serialization
        address tokenAddress;
        // uint8 nameLength
        string name;
        // uint8 symbolLength
        string symbol;
        uint8 decimals;
    }

    /// Serialize addToken opdata
    function writeAddTokenOpDataForPriorityQueue(AddToken memory op) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            uint8(OpType.AddToken),
            op.tokenAddress,
            uint8(bytes(op.name).length),
            op.name,
            uint8(bytes(op.symbol).length),
            op.symbol,
            op.decimals
        );
    }

    // Withdraw opdata
    struct Withdraw {
        // uint8 opType; -- present in opdata, ignored at serialization
        address zkSyncTokenAddress;
        uint256 amount;
        address to;
    }

    function readWithdrawOpData(bytes memory _data, uint256 offset)
        internal
        pure
        returns (uint256 newOffset, Withdraw memory parsed)
    {
        offset += OP_TYPE_BYTES; // opType
        (offset, parsed.zkSyncTokenAddress) = Bytes.readAddress(_data, offset);
        (offset, parsed.amount) = Bytes.readUInt256(_data, offset);
        (offset, parsed.to) = Bytes.readAddress(_data, offset);
        newOffset = offset;
    }

    /// Serialize withdraw opdata
    function writeWithdrawOpDataForPriorityQueue(Withdraw memory op) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(uint8(OpType.Withdraw), op.zkSyncTokenAddress, op.amount, op.to);
    }

    // Execute opdata
    struct Execute {
        // uint8 opType; -- present in opdata, ignored at serialization
        address contractAddressL2;
        uint256 ergsLimit;
        bytes callData;
    }

    function writeExecuteOpDataForPriorityQueue(Execute memory op) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            uint8(OpType.Execute),
            op.contractAddressL2,
            op.ergsLimit,
            uint32(op.callData.length),
            op.callData
        );
    }

    // DeployContract opdata
    struct DeployContract {
        // uint8 opType; -- present in opdata, ignored at serialization
        uint256 ergsLimit;
        bytes bytecode;
        bytes callData;
    }

    function writeDeployContractOpDataForPriorityQueue(DeployContract memory op)
        internal
        pure
        returns (bytes memory buf)
    {
        buf = abi.encodePacked(
            uint8(OpType.DeployContract),
            op.ergsLimit,
            uint32(op.bytecode.length),
            op.bytecode,
            uint32(op.callData.length),
            op.callData
        );
    }
}

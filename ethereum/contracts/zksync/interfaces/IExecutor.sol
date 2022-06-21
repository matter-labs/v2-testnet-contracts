// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8;

import "../Operations.sol";

interface IExecutor {
    struct PublicWithSignature {
        bytes pubkey;
        bytes signature;
    }

    /// @notice Rollup block stored data
    /// @param blockNumber Rollup block number
    /// @param numberOfLayer1Txs Number of priority operations to be processed
    /// @param priorityOperationsComplexity Complexity of the work performed for the processing all priority operations from this block
    /// @param priorityOperationsHash Hash of all priority operations from this block
    /// @param l2LogsTreeRoot root hash of tree that contain L2 -> L1 message from this block
    /// @param timestamp Rollup block timestamp, have the same format as Ethereum block constant
    /// @param stateRoot Root hash of the rollup state
    /// @param commitment Verified input for the zkSync circuit
    struct StoredBlockInfo {
        uint32 blockNumber;
        uint16 numberOfLayer1Txs;
        uint224 priorityOperationsComplexity;
        bytes32 priorityOperationsHash;
        bytes32 l2LogsTreeRoot;
        uint256 timestamp;
        bytes32 stateRoot;
        bytes32 commitment;
    }

    /// @notice Data needed to commit new block
    /// @param newStateRoot The state root of the full state tree.
    /// @param blockNumber Number of the committed block.
    /// @param feeAccount ID of the account that received the fees collected in the block.
    /// @param timestamp Unix timestamp denoting the start of the block execution.
    /// @param priorityOperationsComplexity Complexity of the work performed for the processing all priority operations from this block
    /// @param priorityOperationsHash Hash of all priority operations from this block
    /// @param l2LogsTreeRoot The root hash of the tree that contains all L2 -> L1 logs in the block
    /// @param l2Logs concatenation of all L2 -> L1 logs in the block
    /// @param l2ArbitraryLengthMessages array of preimages of the hashes that were sent as value of L2 logs by special system L2 contract
    /// @param deployedContracts Bytecode of deployed smart contracts
    /// @param storageChanges Storage write access in the compact form
    struct CommitBlockInfo {
        bytes32 newStateRoot;
        uint32 blockNumber;
        address feeAccount;
        uint256 timestamp;
        uint224 priorityOperationsComplexity;
        uint16 numberOfLayer1Txs;
        uint16 numberOfLayer2Txs;
        bytes32 priorityOperationsHash;
        bytes32 l2LogsTreeRoot;
        bytes l2Logs;
        bytes[] l2ArbitraryLengthMessages;
        bytes deployedContracts;
        bytes storageChanges;
    }

    /// @notice Recursive proof input data (individual commitments are constructed onchain)
    struct ProofInput {
        uint256[] recursiveInput;
        uint256[] proof;
        uint256[] commitments;
        uint8[] vkIndexes;
        uint256[16] subproofsLimbs;
    }

    function commitBlocks(StoredBlockInfo calldata _lastCommittedBlockData, CommitBlockInfo[] calldata _newBlocksData)
        external;

    function proveBlocks(StoredBlockInfo[] calldata _committedBlocks, ProofInput memory _proof) external;

    function executeBlocks(StoredBlockInfo[] calldata _blocksData) external;

    function revertBlocks(uint32 _blocksToRevert) external;

    function movePriorityOpsFromBufferToMainQueue(uint256 _nOpsToMove, OpTree _opTree) external;

    /// @notice Event emitted when a block is committed
    event BlockCommit(uint32 indexed blockNumber);

    /// @notice Event emitted when a block is executed
    event BlockExecution(uint32 indexed blockNumber);

    /// @notice Moving priority operations from buffer to heap event
    event MovePriorityOperationsFromBufferToHeap(uint32 expirationBlock, uint64[] operationIDs, OpTree opTree);

    /// @notice Event emitted when blocks are reverted
    event BlocksRevert(uint32 totalBlocksVerified, uint32 totalBlocksCommitted);
}

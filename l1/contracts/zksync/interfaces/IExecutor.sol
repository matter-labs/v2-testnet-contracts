pragma solidity ^0.8;

// SPDX-License-Identifier: MIT OR Apache-2.0



interface IExecutor {
    /// @notice Rollup block stored data
    /// @param blockNumber Rollup block number
    /// @param numberOfLayer1Txs Number of priority operations to be processed
    /// @param priorityOperationsHash Hash of all priority operations from this block
    /// @param l2LogsTreeRoot root hash of tree that contain L2 -> L1 message from this block
    /// @param timestamp Rollup block timestamp, have the same format as Ethereum block constant
    /// @param stateRoot Root hash of the rollup state
    /// @param commitment Verified input for the zkSync circuit
    struct StoredBlockInfo {
        uint32 blockNumber;
        uint16 numberOfLayer1Txs;
        bytes32 priorityOperationsHash;
        bytes32 l2LogsTreeRoot;
        bytes32 stateRoot;
        bytes32 commitment;
    }

    /// @notice Data needed to commit new block
    /// @param newStateRoot The state root of the full state tree.
    /// @param blockNumber Number of the committed block.
    /// @param feeAccount ID of the account that received the fees collected in the block.
    /// @param timestamp Unix timestamp denoting the start of the block execution.
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

    function revertBlocks(uint256 _blocksToRevert) external;

    /// @notice Event emitted when a block is committed
    event BlockCommit(uint256 indexed blockNumber);

    /// @notice Event emitted when a block is executed
    event BlockExecution(uint256 indexed blockNumber);

    /// @notice Event emitted when blocks are reverted
    event BlocksRevert(uint256 totalBlocksVerified, uint256 totalBlocksCommitted);
}

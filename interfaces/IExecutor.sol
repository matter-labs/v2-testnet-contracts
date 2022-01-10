pragma solidity ^0.8;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../libraries/Operations.sol";

interface IExecutor {
    struct PublicWithSignature {
        bytes pubkey;
        bytes signature;
    }

    // Quorum sigs structure as defined in notion spec (except for `status` field).
    struct QuorumSigs {
        // Block number
        uint32 round;
        // Signatures.
        PublicWithSignature[] sigs;
        uint32 stake;
    }

    /// @notice Rollup block stored data
    /// @param blockNumber Rollup block number
    /// @param numberOfLayer1Txs Number of priority operations to be processed
    /// @param numberOfLayer2Txs Number of transactions that were requested offchain
    /// @param priorityOperationsComplexity Complexity of the work performed for the processing all priority operations from this block
    /// @param processableOnchainOperationsHash Hash of all operations which require interaction L2 -> L1 (e.g. Withdrawal)
    /// @param priorityOperationsHash Hash of all priority operations from this block
    /// @param timestamp Rollup block timestamp, have the same format as Ethereum block constant
    /// @param stateRoot Root hash of the rollup state
    /// @param zkPorterHash Root hash of zkPorter subtree
    /// @param commitment Verified input for the zkSync circuit
    struct StoredBlockInfo {
        uint32 blockNumber;
        uint16 numberOfLayer1Txs;
        uint16 numberOfLayer2Txs;
        uint224 priorityOperationsComplexity;
        bytes32 processableOnchainOperationsHash;
        bytes32 priorityOperationsHash;
        uint256 timestamp;
        bytes32 stateRoot;
        bytes32 zkPorterRoot;
        bytes32 commitment;
    }

    /// @notice Data needed to commit new block
    /// @param newStateRoot The state root of the full state tree.
    /// @param zkPorterRoot The root hash of zkPorter subtree.
    /// @param blockNumber Number of the committed block.
    /// @param feeAccount ID of the account that received the fees collected in the block.
    /// @param timestamp Unix timestamp denoting the start of the block execution.
    /// @param priorityOperationsComplexity Complexity of the work performed for the processing all priority operations from this block
    /// @param processableOnchainOperationsHash Hash of all operations whith should be processed in block execution (e.g Withdrawal)
    /// @param priorityOperationsHash Hash of all priority operations from this block
    /// @param deployedContracts Bytecode of deployed smart contracts.
    /// @param storageUpdateLogs Storage write access logs in the compact form.
    struct CommitBlockInfo {
        bytes32 newStateRoot;
        bytes32 zkPorterRoot;
        uint32 blockNumber;
        address feeAccount;
        uint256 timestamp;
        uint224 priorityOperationsComplexity;
        uint16 numberOfLayer1Txs;
        uint16 numberOfLayer2Txs;
        bytes32 processableOnchainOperationsHash;
        bytes32 priorityOperationsHash;
        bytes deployedContracts;
        bytes storageUpdateLogs;
        // zkPorter data is being committed with each block, but it's not used in any way currently.
        QuorumSigs zkPorterData;
    }

    /// @notice Data needed to execute committed and verified block
    struct ExecuteBlockInfo {
        StoredBlockInfo storedBlock;
        bytes processableOnchainOperations;
    }

    /// @notice Recursive proof input data (individual commitments are constructed onchain)
    struct ProofInput {
        uint256[] recursiveInput;
        uint256[] proof;
        uint256[] commitments;
        uint8[] vkIndexes;
        uint256[16] subproofsLimbs;
    }

    function commitBlocks(StoredBlockInfo memory _lastCommittedBlockData, CommitBlockInfo[] memory _newBlocksData)
        external;

    function executeBlocks(ExecuteBlockInfo[] memory _blocksData) external;

    function proveBlocks(StoredBlockInfo[] memory _committedBlocks, ProofInput memory _proof) external;

    function revertBlocks(uint32 _blocksToRevert) external;

    function movePriorityOpsFromBufferToMainQueue(uint256 _nOpsToMove, Operations.OpTree _opTree) external;

    /// @notice Event emitted when a block is committed
    event BlockCommit(uint32 indexed blockNumber);

    /// @notice Event emitted when a block is executed
    event BlockExecution(uint32 indexed blockNumber);

    /// @notice Moving priority operations from buffer to heap event
    event MovePriorityOperationsFromBufferToHeap(
        uint32 expirationBlock,
        uint64[] operationIDs,
        Operations.OpTree opTree
    );

    /// @notice Event emitted when blocks are reverted
    event BlocksRevert(uint32 totalBlocksVerified, uint32 totalBlocksCommitted);
}

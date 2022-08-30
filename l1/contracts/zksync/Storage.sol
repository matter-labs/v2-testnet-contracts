pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./Verifier.sol";
import "./libraries/PriorityQueue.sol";

struct DiamondCutStorage {
    bytes32 proposedDiamondCutHash;
    uint256 proposedDiamondCutTimestamp;
    uint256 lastDiamondFreezeTimestamp;
    uint256 currentProposalId;
    mapping(address => bool) securityCouncilMembers;
    mapping(address => uint256) securityCouncilMemberLastApprovedProposalId;
    uint256 securityCouncilEmergencyApprovals;
}

/// @dev log passed from L2
struct L2Log {
    address sender;
    bytes32 key;
    bytes32 value;
}

/// @dev arbitrary length message passed from L2
/// @notice under the hood it is `L2Log` sent from the special system L2 contract
/// @param sender address of the L2 account from which the message was passed
/// @param data arbitrary length message
struct L2Message {
    address sender;
    bytes data;
}

/// @dev storing all storage variables for zkSync facets
/// NOTE: It is used in a proxy, so it is possible to add new variables to the end
/// NOTE: but NOT to modify already existing variables or change their order
struct AppStorage {
    /// @dev Storage of variables needed for diamond cut facet
    DiamondCutStorage diamondCutStorage;
    /// @notice Address which will exercise governance over the network i.e. change validator set, conduct upgrades
    address governor;
    /// @notice Address that governor proposed as one that will replace it
    address pendingGovernor;
    /// @notice List of permitted validators
    mapping(address => bool) validators;
    // TODO: should be used an external library approach
    /// @dev Verifier contract. Used to verify aggregated proof for blocks
    Verifier verifier;
    /// @notice Total number of executed blocks i.e. blocks[totalBlocksExecuted] points at the latest executed block (block 0 is genesis)
    uint256 totalBlocksExecuted;
    /// @notice Total number of proved blocks i.e. blocks[totalBlocksProved] points at the latest proved block
    uint256 totalBlocksVerified;
    /// @notice Total number of committed blocks i.e. blocks[totalBlocksCommitted] points at the latest committed block
    uint256 totalBlocksCommitted;
    /// @dev Stored hashed StoredBlock for block number
    mapping(uint256 => bytes32) storedBlockHashes;
    /// @dev Stored root hashes of L2 -> L1 logs
    mapping(uint256 => bytes32) l2LogsRootHashes;
    /// @dev Container that stores transactions requested from L1
    PriorityQueue.Queue priorityQueue;
}

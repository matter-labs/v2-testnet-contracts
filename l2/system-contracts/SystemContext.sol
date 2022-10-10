// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import { SystemContractHelper } from "./SystemContractHelper.sol";
import { ISystemContext } from "./interfaces/ISystemContext.sol";
import "./Constants.sol";

/**
 * @author Matter Labs
 * @notice Contract that stores some of the context variables, that may be either 
 * block-scoped, tx-scoped or system-wide.
 */
contract SystemContext is ISystemContext {
    modifier onlyBootloader {
        require(msg.sender == BOOTLOADER_FORMAL_ADDRESS);
        _;
    }
    
    uint256 public chainId = 270;
    address public origin;
    uint256 public ergsPrice;
    // Some dummy value, maybe will be possible to change it in the future.
    uint256 public blockErgsLimit = (1 << 30);
    // For the support of coinbase, we will the bootloader formal address for now
    address public coinbase = BOOTLOADER_FORMAL_ADDRESS;
    // For consistency with other L2s
    uint256 public difficulty = 2500000000000000;
    uint256 public msize = (1 << 24);
    uint256 public baseFee;
    
    uint256 constant BLOCK_INFO_BLOCK_NUMBER_PART = (1<<128);
    // 2^128 * block_number + block_timestamp
    uint256 public currentBlockInfo;

    mapping(uint256 => bytes32) public blockHash;

    function setTxOrigin(address _newOrigin) external onlyBootloader {
        origin = _newOrigin;
    }

    function setErgsPrice(uint256 _ergsPrice) external onlyBootloader {
        ergsPrice = _ergsPrice;
    }

    function getBlockHashEVM(uint256 _block) external view returns (bytes32 hash) {
        if(block.number < _block || block.number - _block > 256) {
            hash = bytes32(0);
        } else {
            hash = blockHash[_block];
        }
    }

    function getBlockNumberAndTimestamp() public view returns (uint256 blockNumber, uint256 blockTimestamp) {
        uint256 blockInfo = currentBlockInfo;
        blockNumber = blockInfo / BLOCK_INFO_BLOCK_NUMBER_PART;
        blockTimestamp = blockInfo % BLOCK_INFO_BLOCK_NUMBER_PART;
    }

    // Note, that for now, the implementation of the bootloader allows this variables to 
    // be incremented multiple times inside a block, so it should not relied upon right now.
    function getBlockNumber() public view returns (uint256 blockNumber) {
        (blockNumber, ) = getBlockNumberAndTimestamp();
    }

    function getBlockTimestamp() public view returns (uint256 timestamp) {
        (, timestamp) = getBlockNumberAndTimestamp();
    }

    /// @dev increments the current block number and sets the new timestamp
    function setNewBlock(bytes32 _blockHash, uint256 _newTimestamp, uint256 _expectedNewNumber) onlyBootloader external {
        (uint256 currentBlockNumber, uint256 currentBlockTimestamp) = getBlockNumberAndTimestamp();
        require(_newTimestamp >= currentBlockTimestamp, "Timestamps should be incremental");
        require(currentBlockNumber + 1 == _expectedNewNumber, "The provided block number is not correct");

        blockHash[currentBlockNumber] = _blockHash;

        // Setting new block number and timestamp
        currentBlockInfo = (currentBlockNumber + 1) * BLOCK_INFO_BLOCK_NUMBER_PART + _newTimestamp;

        // The correctness of this block hash and the timestamp will be checked on L1:
        SystemContractHelper.toL1(false, bytes32(_newTimestamp), _blockHash);
    }

    // Should be used only for testing / execution and should never be used in production.
    function unsafeOverrideBlock(uint256 _newTimestamp, uint256 number) onlyBootloader external {
        currentBlockInfo = (number) * BLOCK_INFO_BLOCK_NUMBER_PART + _newTimestamp;
    }
}

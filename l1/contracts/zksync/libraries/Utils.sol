pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../Config.sol";
import "../Storage.sol";

library Utils {
    /// @notice Event emitted when blocks are reverted
    event BlocksRevert(uint32 totalBlocksVerified, uint32 totalBlocksCommitted);

    /// @notice Returns lesser of two values
    function minU256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Returns larger of two values
    function maxU32(uint32 a, uint32 b) internal pure returns (uint32) {
        return a < b ? b : a;
    }

    function burnEther(uint256 _value) internal {
        (bool success, ) = address(0).call{value: _value}("");
        require(success);
    }

    /// @notice Reverts unexecuted blocks
    /// @param _newLastBlock block number after which blocks should be reverted
    /// NOTE: Doesn't delete the stored data about blocks, but only decreases
    /// counters that are responsible for the number of blocks
    function revertBlocks(AppStorage storage s, uint32 _newLastBlock) internal {
        require(s.totalBlocksCommitted >= _newLastBlock, "v1"); // the last committed block is less new last block
        s.totalBlocksCommitted = maxU32(_newLastBlock, s.totalBlocksExecuted);

        if (s.totalBlocksCommitted < s.totalBlocksVerified) {
            s.totalBlocksVerified = s.totalBlocksCommitted;
        }

        emit BlocksRevert(s.totalBlocksExecuted, s.totalBlocksCommitted);
    }

    /// @notice Recovers signer's address from ethereum signature for given message
    /// @param _signature 65 bytes concatenated. R (32) + S (32) + V (1)
    /// @param _messageHash signed message hash.
    /// @return address of the signer
    function recoverAddressFromEthSignature(bytes memory _signature, bytes32 _messageHash)
        internal
        pure
        returns (address)
    {
        require(_signature.length == 65, "P"); // incorrect signature length

        bytes32 signR;
        bytes32 signS;
        uint8 signV;
        assembly {
            signR := mload(add(_signature, 32))
            signS := mload(add(_signature, 64))
            signV := byte(0, mload(add(_signature, 96)))
        }

        return ecrecover(_messageHash, signV, signR, signS);
    }

    function hashBytesToBytes16(bytes memory _bytes) internal pure returns (bytes16) {
        return bytes16(uint128(uint256(keccak256(_bytes))));
    }

    function isContract(address _address) internal view returns (bool) {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_address)
        }

        return contractSize != 0;
    }
}

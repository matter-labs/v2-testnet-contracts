pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



/// @author Matter Labs
library Merkle {
    function calculateRoot(
        bytes32[] memory _path,
        uint256 _index,
        bytes32 _itemHash
    ) internal pure returns (bytes32) {
        uint256 pathLength = _path.length;
        require(pathLength <= 256, "xc");

        bytes32 currentHash = _itemHash;
        for (uint256 i = 0; i < pathLength; ++i) {
            if (_index % 2 == 0) {
                currentHash = sha256(abi.encodePacked(currentHash, _path[i]));
            } else {
                currentHash = sha256(abi.encodePacked(_path[i], currentHash));
            }
            _index /= 2;
        }

        return currentHash;
    }
}

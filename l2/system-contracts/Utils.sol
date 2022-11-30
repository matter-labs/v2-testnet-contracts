// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

/**
 * @author Matter Labs
 * @dev Common utilities used in zkSync system contracts
 */
library Utils {
    function safeCastToU24(uint256 x) internal pure returns (uint24) {
        require(x < 2**24, "Overflow");

        return uint24(x);
    }
}

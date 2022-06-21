// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "../../libraries/Utils.sol";

contract ZKSyncSignatureUnitTest {
    function testRecoverAddressFromEthSignature(bytes memory _signature, bytes32 _messageHash)
        external
        pure
        returns (address)
    {
        return Utils.recoverAddressFromEthSignature(_signature, _messageHash);
    }
}

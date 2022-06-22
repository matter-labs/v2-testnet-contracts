pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED



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

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "./interfaces/IL1Bridge.sol";
import "./interfaces/IL2Bridge.sol";
import "./interfaces/IL2StandardToken.sol";

import "./L2StandardERC20.sol";
import {L2ContractHelper} from "../L2ContractHelper.sol";

/// @author Matter Labs
contract L2ERC20Bridge is IL2Bridge {
    address public immutable override l1Bridge;
    bytes32 immutable l2TokenBytecodeHash;

    /// @dev mapping l2 token address => l1 token address
    mapping(address => address) public override l1TokenAddress;

    constructor(address _l1Bridge, bytes32 _l2StandardERC20BytecodeHash) {
        l1Bridge = _l1Bridge;
        l2TokenBytecodeHash = _l2StandardERC20BytecodeHash;
    }

    function finalizeDeposit(
        address, // _l1Sender
        address _l2Receiver,
        address _l1Token,
        uint256 _amount,
        bytes calldata _data
    ) external override {
        require(msg.sender == l1Bridge);

        address expectedL2Token = l2TokenAddress(_l1Token);
        if (l1TokenAddress[expectedL2Token] == address(0)) {
            address depoyedToken = _deployL2Token(_l1Token, _data);
            require(depoyedToken == expectedL2Token);
            l1TokenAddress[expectedL2Token] = _l1Token;
        }

        IL2StandardToken(expectedL2Token).bridgeMint(_l2Receiver, _amount);
    }

    function _deployL2Token(address _l1Token, bytes calldata _data) internal returns (address) {
        bytes32 salt = _getCreate2Salt(_l1Token);

        L2StandardERC20 l2Token = new L2StandardERC20{salt: salt}();
        l2Token.bridgeInitialize(_l1Token, _data);

        return address(l2Token);
    }

    function withdraw(
        address _l1Receiver,
        address _l2Token,
        uint256 _amount
    ) external override {
        IL2StandardToken(_l2Token).bridgeBurn(msg.sender, _amount);

        address l1Token = l1TokenAddress[_l2Token];
        require(l1Token != address(0));

        bytes memory message = _getL1WithdrawMessage(_l1Receiver, l1Token, _amount);
        L2ContractHelper.sendMessageToL1(message);
    }

    function _getL1WithdrawMessage(
        address _to,
        address _l1Token,
        uint256 _amount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(IL1Bridge.finalizeWithdrawal.selector, _to, _l1Token, _amount);
    }

    function l2TokenAddress(address _l1Token) public view override returns (address) {
        bytes32 constructorInputHash = keccak256("");
        bytes32 salt = _getCreate2Salt(_l1Token);

        return L2ContractHelper.computeCreate2Address(address(this), salt, l2TokenBytecodeHash, constructorInputHash);
    }

    function _getCreate2Salt(address _l1Token) internal pure returns (bytes32 salt) {
        salt = bytes32(uint256(uint160(_l1Token)));
    }
}

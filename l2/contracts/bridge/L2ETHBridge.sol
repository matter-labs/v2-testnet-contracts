// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import {L2ContractHelper} from "../L2ContractHelper.sol";

import "./interfaces/IL1Bridge.sol";
import "./interfaces/IL2Bridge.sol";
import "./interfaces/IL2EthInitializable.sol";
import "./interfaces/IL2StandardToken.sol";

/**
 * @author Matter Labs
 * @dev This contract is used for bridging the ether from L1.
 */
contract L2ETHBridge is IL2Bridge {
    /// @dev The total amount of tokens that have been minted.
    uint256 public totalSupply;

    /// @dev Mapping of address to the balance.
    mapping(address => uint256) public balanceOf;

    /// @dev Address of the L1 bridge counterpart.
    address public override l1Bridge;

    /// @dev System contract that is responsible for storing and changing ether balances.
    IL2StandardToken constant ETH_TOKEN_SYSTEM_CONTRACT_ADDRESS = IL2StandardToken(address(0x800a));

    /// @dev Ether native coin has no real address on L1, so a conventional zero address is used.
    address constant CONVENTIONAL_ETH_ADDRESS = address(0);

    constructor(address _l1Bridge) {
        l1Bridge = _l1Bridge;

        IL2EthInitializable(address(ETH_TOKEN_SYSTEM_CONTRACT_ADDRESS)).initialization(address(this));
    }

    /// @dev handle a deposit transaction from the L1 bridge.
    function finalizeDeposit(
        address _l1Sender,
        address _l2Receiver,
        address _l1Token,
        uint256 _amount,
        bytes calldata // _data
    ) external {
        require(msg.sender == l1Bridge);
        require(_l1Token == CONVENTIONAL_ETH_ADDRESS);

        ETH_TOKEN_SYSTEM_CONTRACT_ADDRESS.bridgeMint(_l2Receiver, _amount);

        emit FinalizeDeposit(_l1Sender, _l2Receiver, CONVENTIONAL_ETH_ADDRESS, _amount);
    }

    /// @dev initiate withdrawal ethers from L2 contract to the L1.
    /// NOTE: In order to get funds on L1, the receiver should finalize the deposit on the L1 counterpart.
    function withdraw(
        address _l1Receiver,
        address _l2Token,
        uint256 _amount
    ) external override {
        require(_l2Token == CONVENTIONAL_ETH_ADDRESS);

        ETH_TOKEN_SYSTEM_CONTRACT_ADDRESS.bridgeBurn(msg.sender, _amount);
        bytes memory message = _getL1WithdrawMessage(_l1Receiver, _amount);
        L2ContractHelper.sendMessageToL1(message);

        emit WithdrawalInitiated(msg.sender, _l1Receiver, CONVENTIONAL_ETH_ADDRESS, _amount);
    }

    /// @dev Get the message to be sent to L1 to initiate a withdrawal.
    function _getL1WithdrawMessage(address _to, uint256 _amount) internal pure returns (bytes memory) {
        return abi.encodePacked(IL1Bridge.finalizeWithdrawal.selector, _to, _amount);
    }

    function l2TokenAddress(address) public pure returns (address) {
        return CONVENTIONAL_ETH_ADDRESS;
    }

    function l1TokenAddress(address) public pure override returns (address) {
        return CONVENTIONAL_ETH_ADDRESS;
    }
}

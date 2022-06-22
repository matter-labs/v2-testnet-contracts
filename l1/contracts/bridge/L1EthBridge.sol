pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./interfaces/IL1Bridge.sol";
import "./interfaces/IL2Bridge.sol";

import "../common/libraries/UnsafeBytes.sol";
import "../common/L2ContractHelper.sol";
import "../common/ReentrancyGuard.sol";

/// @author Matter Labs
contract L1EthBridge is IL1Bridge, ReentrancyGuard {
    // TODO: evaluate constant
    uint256 constant DEPOSIT_ERGS_LIMIT = 2097152;
    // TODO: evaluate constant
    uint256 constant DEPLOY_L2_BRIDGE_COUNTERPART_ERGS_LIMIT = 2097152;

    /// @dev Ether native coin has no real address on L2, so a conventional zero address is used
    address constant L2_ETH_ADDRESS = address(0);

    /// @dev Ether native coin has no real address on L1, so a conventional zero address is used
    address constant L1_ETH_ADDRESS = address(0);

    mapping(uint32 => mapping(uint256 => bool)) isL2ToL1MessageProcessed;

    mapping(address => mapping(bytes32 => uint256)) depositAmount;

    /// @dev address of deployed L2 bridge counterpart
    address public l2Bridge;

    IMailbox immutable zkSyncMailbox;

    constructor(IMailbox _mailbox) {
        zkSyncMailbox = _mailbox;
    }

    function initialize(bytes calldata _l2BridgeBytecode) external {
        require(l2Bridge == address(0)); // already initialized
        initializeReentrancyGuard();

        bytes32 create2Salt = bytes32(0);
        bytes memory create2Input = abi.encode(address(this));
        bytes32 l2BridgeBytecodeHash = L2ContractHelper.hashL2Bytecode(_l2BridgeBytecode);
        bytes memory deployL2BridgeCalldata = abi.encodeWithSelector(
            IContractDeployer.create2.selector,
            create2Salt,
            l2BridgeBytecodeHash,
            0,
            create2Input
        );

        l2Bridge = L2ContractHelper.computeCreate2Address(
            address(this),
            create2Salt,
            l2BridgeBytecodeHash,
            keccak256(create2Input)
        );
        bytes[] memory factoryDeps = new bytes[](1);
        factoryDeps[0] = _l2BridgeBytecode;
        zkSyncMailbox.requestL2Transaction(
            DEPLOYER_SYSTEM_CONTRACT_ADDRESS,
            deployL2BridgeCalldata,
            DEPLOY_L2_BRIDGE_COUNTERPART_ERGS_LIMIT,
            factoryDeps,
            QueueType.Deque
        );
    }

    function deposit(
        address _l2Receiver,
        address _l1Token,
        uint256 _amount,
        QueueType _queueType
    ) external payable nonReentrant returns (bytes32 txHash) {
        require(_l1Token == L1_ETH_ADDRESS);

        // Will revert if msg.value is less than the amount of the deposit
        uint256 zkSyncFee = msg.value - _amount;
        bytes memory l2TxCalldata = _getDepositL2Calldata(msg.sender, _l2Receiver, _amount);
        txHash = zkSyncMailbox.requestL2Transaction{value: zkSyncFee}(
            l2Bridge,
            l2TxCalldata,
            DEPOSIT_ERGS_LIMIT,
            new bytes[](0),
            _queueType
        );

        // Save deposit amount, to claim funds back if the L2 transaction will failed
        depositAmount[msg.sender][txHash] = _amount;
    }

    /// @dev serialize the transaction calldata for L2 bridge counterpart
    function _getDepositL2Calldata(
        address _l1Sender,
        address _l2Receiver,
        uint256 _amount
    ) internal pure returns (bytes memory txCalldata) {
        txCalldata = abi.encodeWithSelector(
            IL2Bridge.finalizeDeposit.selector,
            _l1Sender,
            _l2Receiver,
            L1_ETH_ADDRESS,
            _amount,
            hex""
        );
    }

    function claimFailedDeposit(
        address _depositSender,
        address _l1Token,
        bytes32 _l2TxHash,
        uint32 _l2BlockNumber,
        uint256 _l2MessageIndex,
        bytes32[] calldata _merkleProof
    ) external override nonReentrant {
        require(_l1Token == L1_ETH_ADDRESS);

        uint256 amount = depositAmount[_depositSender][_l2TxHash];
        require(amount != 0);

        L2Log memory l2Log = L2Log({sender: BOOTLOADER_ADDRESS, key: _l2TxHash, value: bytes32(0)});
        bool success = zkSyncMailbox.proveL2LogInclusion(_l2BlockNumber, _l2MessageIndex, l2Log, _merkleProof);
        require(success);

        depositAmount[_depositSender][_l2TxHash] = 0;

        _withdrawFunds(_depositSender, amount);
    }

    function finalizeWithdrawal(
        uint32 _l2BlockNumber,
        uint256 _l2MessageIndex,
        bytes calldata _message,
        bytes32[] calldata _merkleProof
    ) external override nonReentrant {
        require(!isL2ToL1MessageProcessed[_l2BlockNumber][_l2MessageIndex]);

        L2Message memory l2ToL1Message = L2Message({sender: l2Bridge, data: _message});

        (address l1Receiver, uint256 amount) = _parseL2WithdrawalMessage(_message);

        bool success = zkSyncMailbox.proveL2MessageInclusion(
            _l2BlockNumber,
            _l2MessageIndex,
            l2ToL1Message,
            _merkleProof
        );
        require(success);

        isL2ToL1MessageProcessed[_l2BlockNumber][_l2MessageIndex] = true;
        _withdrawFunds(l1Receiver, amount);
    }

    function _parseL2WithdrawalMessage(bytes memory _message)
        internal
        pure
        returns (address l1Receiver, uint256 amount)
    {
        // Check that message length is correct.
        // It should be equal to the length of the function signature + address + uint256 = 4 + 20 + 32 = 56 (bytes).
        require(_message.length == 56);

        (uint32 functionSignature, uint256 offset) = UnsafeBytes.readUint32(_message, 0);
        require(bytes4(functionSignature) == this.finalizeWithdrawal.selector);

        (l1Receiver, offset) = UnsafeBytes.readAddress(_message, offset);
        (amount, offset) = UnsafeBytes.readUint256(_message, offset);
    }

    function _withdrawFunds(address _to, uint256 _amount) internal {
        (bool callSuccess, ) = _to.call{value: _amount}("");
        require(callSuccess);
    }

    function l2TokenAddress(address _l1Token) public pure returns (address l2Token) {
        if (_l1Token == L1_ETH_ADDRESS) {
            l2Token = L2_ETH_ADDRESS;
        }
    }
}

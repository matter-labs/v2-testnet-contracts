pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./interfaces/IL1Bridge.sol";
import "./interfaces/IL2Bridge.sol";

import "../common/interfaces/IERC20.sol";
import "../common/libraries/UnsafeBytes.sol";
import "../common/ReentrancyGuard.sol";
import "../common/L2ContractHelper.sol";

/// @author Matter Labs
contract L1ERC20Bridge is IL1Bridge, ReentrancyGuard {
    // TODO: evaluate constant
    uint256 constant DEPOSIT_ERGS_LIMIT = 2097152;

    // TODO: evaluate constant
    uint256 constant DEPLOY_L2_BRIDGE_COUNTERPART_ERGS_LIMIT = 2097152;

    /// @dev mapping L2 block number => message number => flag
    /// @dev Used to indicated that zkSync L2 -> L1 message was already processed
    mapping(uint32 => mapping(uint256 => bool)) isL2ToL1MessageProcessed;

    /// @dev mapping account => L1 token address => L2 deposit transaction hash => amount
    /// @dev Used for saving amount of deposited fund, to claim them in case if deposit transaction will failed
    mapping(address => mapping(address => mapping(bytes32 => uint256))) depositAmount;

    /// @dev address of deployed L2 bridge counterpart
    address public l2Bridge;

    /// @dev bytecode hash of L2 token contract
    bytes32 public l2StandardERC20BytecodeHash;

    /// @dev zkSync smart contract that used to operate with L2 via asychronous L2 <-> L1 communication
    IMailbox immutable zkSyncMailbox;

    constructor(IMailbox _mailbox) {
        zkSyncMailbox = _mailbox;
    }

    function initialize(bytes calldata _l2BridgeBytecode, bytes calldata _l2StandardERC20Bytecode) external {
        require(l2Bridge == address(0)); // already initialized
        require(l2StandardERC20BytecodeHash == 0x00); // already initialized
        l2StandardERC20BytecodeHash = L2ContractHelper.hashL2Bytecode(_l2StandardERC20Bytecode);

        initializeReentrancyGuard();

        bytes32 create2Salt = bytes32(0);
        bytes memory create2Input = abi.encode(address(this), l2StandardERC20BytecodeHash);
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
        bytes[] memory factoryDeps = new bytes[](2);
        factoryDeps[0] = _l2BridgeBytecode;
        factoryDeps[1] = _l2StandardERC20Bytecode;

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
        uint256 amount = _depositFunds(msg.sender, IERC20(_l1Token), _amount);
        require(amount > 0, "1T"); // empty deposit amount

        bytes memory l2TxCalldata = _getDepositL2Calldata(msg.sender, _l2Receiver, _l1Token, amount);
        txHash = zkSyncMailbox.requestL2Transaction{value: msg.value}(
            l2Bridge,
            l2TxCalldata,
            DEPOSIT_ERGS_LIMIT,
            new bytes[](0),
            _queueType
        );

        depositAmount[msg.sender][_l1Token][txHash] = amount;
    }

    function _depositFunds(
        address _from,
        IERC20 _token,
        uint256 _amount
    ) internal returns (uint256) {
        uint256 balanceBefore = _token.balanceOf(address(this));
        _token.transferFrom(_from, address(this), _amount);
        uint256 balanceAfter = _token.balanceOf(address(this));

        return balanceAfter - balanceBefore;
    }

    function _getDepositL2Calldata(
        address _l1Sender,
        address _l2Receiver,
        address _l1Token,
        uint256 _amount
    ) internal view returns (bytes memory txCalldata) {
        // TODO: shouldn't be requested for every deposit
        bytes memory gettersData = _getERC20Getters(_l1Token);

        txCalldata = abi.encodeWithSelector(
            IL2Bridge.finalizeDeposit.selector,
            _l1Sender,
            _l2Receiver,
            _l1Token,
            _amount,
            gettersData
        );
    }

    /// @dev receives and parses (name, symbol, decimals) from token contract
    function _getERC20Getters(address _token) internal view returns (bytes memory data) {
        (, bytes memory data1) = _token.staticcall(abi.encodeWithSelector(IERC20.name.selector));
        (, bytes memory data2) = _token.staticcall(abi.encodeWithSelector(IERC20.symbol.selector));
        (, bytes memory data3) = _token.staticcall(abi.encodeWithSelector(IERC20.decimals.selector));
        data = abi.encode(data1, data2, data3);
    }

    /// @dev withdraw funds for a failed deposit
    function claimFailedDeposit(
        address _depositSender,
        address _l1Token,
        bytes32 _l2TxHash,
        uint32 _l2BlockNumber,
        uint256 _l2MessageIndex,
        bytes32[] calldata _merkleProof
    ) external nonReentrant {
        L2Log memory l2Log = L2Log({sender: BOOTLOADER_ADDRESS, key: _l2TxHash, value: bytes32(0)});
        bool success = zkSyncMailbox.proveL2LogInclusion(_l2BlockNumber, _l2MessageIndex, l2Log, _merkleProof);
        require(success);

        uint256 amount = depositAmount[_depositSender][_l1Token][_l2TxHash];
        require(amount > 0);

        depositAmount[_depositSender][_l1Token][_l2TxHash] = 0;
        _withdrawFunds(_depositSender, IERC20(_l1Token), amount);
    }

    function finalizeWithdrawal(
        uint32 _l2BlockNumber,
        uint256 _l2MessageIndex,
        bytes calldata _message,
        bytes32[] calldata _merkleProof
    ) external nonReentrant {
        require(!isL2ToL1MessageProcessed[_l2BlockNumber][_l2MessageIndex], "pw");

        L2Message memory l2ToL1Message = L2Message({sender: l2Bridge, data: _message});

        (address l1Receiver, address l1Token, uint256 amount) = _parseL2WithdrawalMessage(l2ToL1Message.data);
        bool success = zkSyncMailbox.proveL2MessageInclusion(
            _l2BlockNumber,
            _l2MessageIndex,
            l2ToL1Message,
            _merkleProof
        );
        require(success, "nq");

        isL2ToL1MessageProcessed[_l2BlockNumber][_l2MessageIndex] = true;
        _withdrawFunds(l1Receiver, IERC20(l1Token), amount);
    }

    function _parseL2WithdrawalMessage(bytes memory _l2ToL1message)
        internal
        pure
        returns (
            address l1Receiver,
            address l1Token,
            uint256 amount
        )
    {
        // Check that message length is correct.
        // It should be equal to the length of the function signature + address + address + uint256 = 4 + 20 + 20 + 32 = 76 (bytes).
        require(_l2ToL1message.length == 76, "kk");

        (uint32 functionSignature, uint256 offset) = UnsafeBytes.readUint32(_l2ToL1message, 0);
        require(bytes4(functionSignature) == this.finalizeWithdrawal.selector, "nt");

        (l1Receiver, offset) = UnsafeBytes.readAddress(_l2ToL1message, offset);
        (l1Token, offset) = UnsafeBytes.readAddress(_l2ToL1message, offset);
        (amount, offset) = UnsafeBytes.readUint256(_l2ToL1message, offset);
    }

    function _withdrawFunds(
        address _to,
        IERC20 _token,
        uint256 _amount
    ) internal returns (uint256) {
        uint256 balanceBefore = _token.balanceOf(address(this));
        _token.transfer(_to, _amount);
        uint256 balanceAfter = _token.balanceOf(address(this));

        return balanceBefore - balanceAfter;
    }

    function l2TokenAddress(address _l1Token) public view returns (address) {
        bytes32 constructorInputHash = keccak256("");
        bytes32 salt = bytes32(uint256(uint160(_l1Token)));

        return
            L2ContractHelper.computeCreate2Address(l2Bridge, salt, l2StandardERC20BytecodeHash, constructorInputHash);
    }
}

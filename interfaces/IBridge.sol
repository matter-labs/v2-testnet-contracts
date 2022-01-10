pragma solidity ^0.8;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./IERC20.sol";

import "../libraries/Operations.sol";

interface IBridge {
    function withdrawPendingBalance(
        address payable _owner,
        address _token,
        uint256 _amount
    ) external;

    function depositBaseCost(
        uint256 _gasPrice,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external view returns (uint256);

    function addTokenBaseCost(
        uint256 _gasPrice,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external view returns (uint256);

    function withdrawBaseCost(
        uint256 _gasPrice,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external view returns (uint256);

    function executeBaseCost(
        uint256 _gasPrice,
        uint256 _ergsLimit,
        uint32 _calldataLength,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external view returns (uint256);

    function deployContractBaseCost(
        uint256 _gasPrice,
        uint256 _ergsLimit,
        uint32 _bytecodeLength,
        uint32 _calldataLength,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external view returns (uint256);

    function depositETH(
        uint256 _amount,
        address _zkSyncAddress,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable;

    function depositERC20(
        IERC20 _token,
        uint256 _amount,
        address _zkSyncAddress,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable;

    function addToken(
        IERC20 _token,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable;

    function addCustomToken(
        address _token,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable;

    function requestWithdraw(
        address _token,
        uint256 _amount,
        address _to,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable;

    function requestExecute(
        address _contractAddressL2,
        bytes memory _calldata,
        uint256 _ergsLimit,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable;

    function requestDeployContract(
        bytes memory _bytecode,
        bytes memory _calldata,
        uint256 _ergsLimit,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable;

    /// @notice New priority request event. Emitted when a request is placed into one of the queue
    event NewPriorityRequest(uint64 serialId, bytes opMetadata);

    /// @notice Event emitted when user funds are withdrawn from the zkSync contract
    event WithdrawPendingBalance(address indexed zkSyncTokenAddress, uint256 amount);
}

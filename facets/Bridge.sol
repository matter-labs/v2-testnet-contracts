pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "../interfaces/IBridge.sol";
import "../interfaces/IERC20.sol";

import "../libraries/Utils.sol";
import "../libraries/Operations.sol";
import "../libraries/WithdrawalHelper.sol";
import "../libraries/PriorityQueue.sol";
import "../libraries/Auction.sol";
import "../libraries/CheckpointedPrefixSum.sol";

import "./Base.sol";

/// @title zkSync Bridge contract providing interfaces for L1 -> L2 interaction.
/// @author Matter Labs
contract BridgeFacet is Base, IBridge {
    using PriorityQueue for PriorityQueue.Queue;
    using CheckpointedPrefixSum for CheckpointedPrefixSum.PrefixSum;

    /// @notice Withdraws tokens from zkSync contract to the owner
    /// @param _owner Address of the tokens owner
    /// @param _token Address of tokens, zero address is used for ETH
    /// @param _amount Amount to withdraw to request.
    /// NOTE: We will call ERC20.transfer(.., _amount), but if according to internal logic of ERC20 token zkSync contract
    /// balance will be decreased by value more then _amount we will try to subtract this value from user pending balance
    function withdrawPendingBalance(
        address payable _owner,
        address _token,
        uint256 _amount
    ) external nonReentrant {
        bool success = false;
        if (_token == ZKSYNC_ETH_ADDRESS) {
            success = WithdrawalHelper.sendETHNoRevert(_owner, _amount);
        } else {
            WithdrawalHelper.sendERC20(IERC20(_token), _owner, _amount);
            success = true;
        }

        require(success, "d"); // withdraw failed
        s.pendingBalances[_owner][_token] -= _amount;
        emit WithdrawPendingBalance(_token, _amount);
    }

    function depositBaseCost(
        uint256 _gasPrice,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) public view returns (uint256) {
        // Subsidize deposit in normal mode
        if (!s.priorityModeState.priorityModeEnabled) {
            return 0;
        }

        return (DEPOSIT_PRIORITY_OPERATION_GAS_COST + _addPriorityOpGasCost(_queueType, _opTree)) * _gasPrice;
    }

    function addTokenBaseCost(
        uint256 _gasPrice,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) public view returns (uint256) {
        return (ADD_TOKEN_PRIORITY_OPERATION_GAS_COST + _addPriorityOpGasCost(_queueType, _opTree)) * _gasPrice;
    }

    function withdrawBaseCost(
        uint256 _gasPrice,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) public view returns (uint256) {
        return (WITHDRAW_PRIORITY_OPERATION_GAS_COST + _addPriorityOpGasCost(_queueType, _opTree)) * _gasPrice;
    }

    function executeBaseCost(
        uint256 _gasPrice,
        uint256 _ergsLimit,
        uint32 _calldataLength,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) public view returns (uint256) {
        // TODO: estimate gas for L1 execute
        return (EXECUTE_CONTRACT_PRIORITY_OPERATION_GAS_COST + _addPriorityOpGasCost(_queueType, _opTree)) * _gasPrice;
    }

    function deployContractBaseCost(
        uint256 _gasPrice,
        uint256 _ergsLimit,
        uint32 _bytecodeLength,
        uint32 _calldataLength,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) public view returns (uint256) {
        // TODO: estimate gas for L1 deployContract
        return (DEPLOY_CONTRACT_WPRIORITY_OPERATION_GAS_COST + _addPriorityOpGasCost(_queueType, _opTree)) * _gasPrice;
    }

    /// @notice Deposit ETH to Layer 2 - transfer ether from user into contract, validate it, register deposit
    /// @param _amount ETH amount
    /// @param _zkSyncAddress The receiver Layer 2 address
    /// @param _queueType Type of data structure in which the priority operation should be stored
    /// @param _opTree Priority operation processing type - Common or OnlyRollup
    function depositETH(
        uint256 _amount,
        address _zkSyncAddress,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable nonReentrant {
        uint256 layer1OpCost = depositBaseCost(tx.gasprice, _queueType, _opTree);
        uint96 layer2Tip = uint96(msg.value - layer1OpCost - _amount);

        Operations.Deposit memory op = Operations.Deposit({
            zkSyncTokenAddress: ZKSYNC_ETH_ADDRESS,
            amount: _amount,
            owner: _zkSyncAddress
        });
        bytes memory opData = Operations.writeDepositOpDataForPriorityQueue(op);

        _addPriorityRequest(_queueType, _opTree, opData, layer1OpCost, layer2Tip);
    }

    /// @notice Deposit ERC20 token to Layer 2 - transfer ERC20 tokens from user into contract, validate it, register deposit
    /// @param _token Token address
    /// @param _amount Token amount
    /// @param _zkSyncAddress Receiver Layer 2 address
    /// @param _queueType Type of data structure in which the priority operation should be stored
    /// @param _opTree Priority operation processing type - Common or OnlyRollup
    function depositERC20(
        IERC20 _token,
        uint256 _amount,
        address _zkSyncAddress,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable nonReentrant {
        uint256 balanceBefore = _token.balanceOf(address(this));
        WithdrawalHelper.transferFromERC20(_token, msg.sender, address(this), _amount);
        uint256 balanceAfter = _token.balanceOf(address(this));
        uint256 depositAmount = balanceAfter - balanceBefore;

        uint256 layer1OpCost = depositBaseCost(tx.gasprice, _queueType, _opTree);
        uint96 layer2Tip = uint96(msg.value - layer1OpCost);

        Operations.Deposit memory op = Operations.Deposit({
            zkSyncTokenAddress: address(_token),
            amount: depositAmount,
            owner: _zkSyncAddress
        });
        bytes memory opData = Operations.writeDepositOpDataForPriorityQueue(op);

        _addPriorityRequest(_queueType, _opTree, opData, layer1OpCost, layer2Tip);
    }

    /// @notice Add token to the list of networks tokens
    /// @param _token Token address
    /// @param _queueType Type of data structure in which the priority operation should be stored
    function addToken(
        IERC20 _token,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable nonReentrant {
        if (!_isGovernor(msg.sender)) {
            // Check that added token indeed has ERC20 interface.
            // We assume that governor will not be malicious, and can use this method
            // to add pre-defined tokens that don't actually correspond to an ERC-20 token,
            // but are processable by the contract nonetheless (e.g. ETH).
            _token.balanceOf(address(this));
        }

        // Since name, symbol and decimals are optional for ERC20 standard
        // but are mandatory for first-citizen tokens
        // we use custom placeholder
        string memory name = "";
        try _token.name() returns (string memory result) {
            name = result;
        } catch {}

        string memory symbol = "";
        try _token.symbol() returns (string memory result) {
            symbol = result;
        } catch {}

        uint8 decimals = 18;
        try _token.decimals() returns (uint8 result) {
            decimals = result;
        } catch {}

        _addToken(address(_token), name, symbol, decimals, _queueType, _opTree);
    }

    // We assume that governor will not be malicious, and can use this method
    // to add pre-defined tokens that don't actually correspond to an ERC-20 token,
    // but are processable by the contract nonetheless (e.g. ETH)
    function addCustomToken(
        address _token,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable nonReentrant {
        _requireGovernor(msg.sender);
        _addToken(_token, _name, _symbol, _decimals, _queueType, _opTree);
    }

    function _addToken(
        address _token,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) internal {
        // Most likely circuit will not support arbitrary-length names & symbols
        // so here we limit the symbol and name by 64 byte length. It is
        // an arbitrary number and may change in the future
        if (bytes(_name).length > MAX_TOKEN_NAME_LENGTH_BYTES) {
            _name = "";
        }

        if (bytes(_symbol).length > MAX_TOKEN_SYMBOL_LENGTH_BYTES) {
            _symbol = "";
        }

        uint256 layer1OpCost = addTokenBaseCost(tx.gasprice, _queueType, _opTree);
        uint96 layer2Tip = uint96(msg.value - layer1OpCost);

        Operations.AddToken memory op = Operations.AddToken({
            tokenAddress: _token,
            name: _name,
            symbol: _symbol,
            decimals: _decimals
        });
        bytes memory opData = Operations.writeAddTokenOpDataForPriorityQueue(op);

        _addPriorityRequest(_queueType, _opTree, opData, layer1OpCost, layer2Tip);
    }

    /// @notice Request a withdrawal operation through the priority queue
    /// @param _token Token address
    /// @param _amount Amount of funds to withdraw
    /// @param _to Address of account to withdraw funds to
    /// @param _queueType Type of data structure in which the priority operation should be stored
    /// @param _opTree Priority operation processing type - Common or OnlyRollup
    function requestWithdraw(
        address _token,
        uint256 _amount,
        address _to,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable nonReentrant {
        address zkSyncTokenAddress = _token;
        if (zkSyncTokenAddress == address(0)) {
            zkSyncTokenAddress = ZKSYNC_ETH_ADDRESS;
        }

        uint256 layer1OpCost = withdrawBaseCost(tx.gasprice, _queueType, _opTree);
        uint96 layer2Tip = uint96(msg.value - layer1OpCost);

        Operations.Withdraw memory op = Operations.Withdraw({
            zkSyncTokenAddress: zkSyncTokenAddress,
            amount: _amount,
            to: _to
        });
        bytes memory opData = Operations.writeWithdrawOpDataForPriorityQueue(op);

        _addPriorityRequest(_queueType, _opTree, opData, layer1OpCost, layer2Tip);
    }

    function requestExecute(
        address _contractAddressL2,
        bytes memory _calldata,
        uint256 _ergsLimit,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable nonReentrant {
        uint256 layer1OpCost = executeBaseCost(tx.gasprice, _ergsLimit, uint8(_calldata.length), _queueType, _opTree);
        uint96 layer2Tip = uint96(msg.value - layer1OpCost);

        Operations.Execute memory op = Operations.Execute({
            contractAddressL2: _contractAddressL2,
            ergsLimit: _ergsLimit,
            callData: _calldata
        });
        bytes memory opData = Operations.writeExecuteOpDataForPriorityQueue(op);

        _addPriorityRequest(_queueType, _opTree, opData, layer1OpCost, layer2Tip);
    }

    function requestDeployContract(
        bytes memory _bytecode,
        bytes memory _calldata,
        uint256 _ergsLimit,
        Operations.QueueType _queueType,
        Operations.OpTree _opTree
    ) external payable nonReentrant {
        uint256 layer1OpCost = deployContractBaseCost(
            tx.gasprice,
            _ergsLimit,
            uint32(_bytecode.length),
            uint32(_calldata.length),
            _queueType,
            _opTree
        );
        uint96 layer2Tip = uint96(msg.value - layer1OpCost);

        Operations.DeployContract memory op = Operations.DeployContract({
            ergsLimit: _ergsLimit,
            bytecode: _bytecode,
            callData: _calldata
        });
        bytes memory opData = Operations.writeDeployContractOpDataForPriorityQueue(op);

        _addPriorityRequest(_queueType, _opTree, opData, layer1OpCost, layer2Tip);
    }

    /// @notice Saves priority request in storage
    /// @dev Calculates expiration block for request, store this request and emit NewPriorityRequest event
    /// @param _queueType Type of data structure in which the priority operation should be stored
    /// @param _opTree Priority operation processing type - Common or OnlyRollup
    /// @param _opData Data about the operation that requests
    /// @param _layer1OpCost Base cost of the operation
    /// @param _layer2Tip Additional tip for the operator to stimulate the processing of operations from the priority queue
    function _addPriorityRequest(
        Operations.QueueType _queueType,
        Operations.OpTree _opTree,
        bytes memory _opData,
        uint256 _layer1OpCost,
        uint96 _layer2Tip
    ) internal {
        require(_queueType == Operations.QueueType.Deque);

        if (_queueType == Operations.QueueType.Heap) {
            PriorityModeLib.State memory state = s.priorityModeState;
            // Block executor take operations from the heap, so this heap should be left unchanged while the operator can produce blocks.
            // Therefore user can add priority operation directly to the heap only when nobody makes blocks - delay sub epoch in priority mode.
            require(state.priorityModeEnabled && state.epoch == PriorityModeLib.Epoch.Delay, "z");
        }

        uint96 layer2TipRemainder = _layer2Tip;
        // Check that queue type is heap or bufferHeap
        if (_queueType != Operations.QueueType.Deque) {
            // It is safe to divide because the value is in WEI
            uint96 burntTip = _layer2Tip / PRIORITY_TRANSACTION_FEE_BURN_COEF;
            layer2TipRemainder = _layer2Tip - burntTip;

            // Burning part of the tip fee
            unchecked {
                s.pendingBalances[address(0)][ZKSYNC_ETH_ADDRESS] += uint256(burntTip);
            }
        }

        address initiatorAddress = msg.sender;
        // TODO: restore after `tx.origin` will work on L2
        // if (Utils.isContract(msg.sender)) {
        //     unchecked {
        //         initiatorAddress = address(uint160(msg.sender) + ADDRESS_ALIAS_OFFSET);
        //     }
        // } else {
        //     initiatorAddress = msg.sender;
        // }

        bytes memory circuitOpData = abi.encodePacked(
            initiatorAddress,
            _opTree,
            _layer1OpCost + uint256(layer2TipRemainder),
            _opData
        );
        bytes16 hashedCircuitOpData = Utils.hashBytesToBytes16(circuitOpData);

        // Expiration block is: current block number + priority expiration delta
        uint32 expirationBlock = _queueType == Operations.QueueType.HeapBuffer
            ? uint32(block.number + PRIORITY_BUFFER_EXPIRATION)
            : uint32(block.number + PRIORITY_EXPIRATION);

        Operations.PriorityOperation memory priorityOp = Operations.PriorityOperation({
            hashedCircuitOpData: hashedCircuitOpData,
            expirationBlock: expirationBlock,
            layer2Tip: layer2TipRemainder
        });

        uint64 priorityOpID = s.totalPriorityRequests;
        s.storedOperations.inner[priorityOpID] = priorityOp;

        if (_queueType == Operations.QueueType.Deque) {
            s.priorityQueue[_opTree].pushBackToDeque(priorityOpID);
        } else if (_queueType == Operations.QueueType.HeapBuffer) {
            s.expiringOpsCounter.bufferHeap[expirationBlock] += 1;
            s.priorityQueue[_opTree].pushToBufferHeap(s.storedOperations, priorityOpID);
        } else {
            s.expiringOpsCounter.heap[expirationBlock] += 1;
            s.priorityQueue[_opTree].pushToHeap(s.storedOperations, priorityOpID);
        }

        bytes memory opMetadata = abi.encodePacked(_queueType, layer2TipRemainder, expirationBlock, circuitOpData);
        emit NewPriorityRequest(priorityOpID, opMetadata);

        s.totalPriorityRequests += 1;
    }

    /// @notice calculates the cost of moving an operation from the buffer to the main queue
    function _addPriorityOpGasCost(Operations.QueueType _queueType, Operations.OpTree _opTree)
        internal
        view
        returns (uint256 cost)
    {
        if (_queueType == Operations.QueueType.HeapBuffer) {
            uint256 totalHeapsHeight = uint256(s.priorityQueue[_opTree].getTotalHeapsHeight());
            // TODO: This formula is not final, but I have no idea how to do it right yet. (SMA-205)
            cost = 2 * (totalHeapsHeight * SSTORENonZeroSlotGasCost + SSTOREZeroSlotGasCost);
        } else if (_queueType == Operations.QueueType.Heap) {
            uint256 heapHeight = uint256(s.priorityQueue[_opTree].heapSize());
            // TODO: This formula is not final, but I have no idea how to do it right yet. (SMA-205)
            cost = 2 * (heapHeight * SSTORENonZeroSlotGasCost + SSTOREZeroSlotGasCost);
        }
    }
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/IL2StandardToken.sol";
import "../ExternalDecoder.sol";

/// @author Matter Labs
contract L2StandardERC20 is ERC20Upgradeable, IL2StandardToken {
    event BridgeInitialization(address indexed l1Token, string name, string symbol, uint8 decimals);

    /// @dev Describes whether there is a specific getter in the token.
    /// @notice Used to explicitly separate which getters the token has and which do not.
    /// @notice Different tokens in L1 can implement or not implement getter function as `name`/`symbol`/`decimals`,
    /// @notice Our goal is store all getter that L1 token implement, and for other we keep it as unimplemented method.
    struct ERC20Getters {
        bool ignoreName;
        bool ignoreSymbol;
        bool ignoreDecimals;
    }

    ERC20Getters availableGetters;

    /// @dev The decimals of the token, that is used as as value for `decimals` getter function.
    /// @notice A private variable is used only for decimals, but not for `name` and `symbol`, because standard
    /// @notice OpenZeppelin token represents `name` and `symbol` as storage variables and `decimals` as constant.
    uint8 private decimals_;

    /// @dev address of the L2 bridge that is used as trustee who can mint/burn tokens.
    address public override l2Bridge;

    /// @dev address of the L1 token that is
    address public override l1Address;

    /// @dev Initializes a contract token for later use
    /// @dev Stores the L1 address of the bridge and set `name`/`symbol`/`decimls` getters that L1 token has.
    function bridgeInitialize(address _l1Address, bytes memory _data) external initializer {
        require(l1Address == address(0), "in5"); // Is already initialized
        require(_l1Address != address(0), "in6"); // Should be non-zero address
        l1Address = _l1Address;

        l2Bridge = msg.sender;

        // We parse the data exactly as they were created on L1 bridge
        (bytes memory nameBytes, bytes memory symbolBytes, bytes memory decimalsBytes) = abi.decode(
            _data,
            (bytes, bytes, bytes)
        );

        ERC20Getters memory getters;
        string memory decodedName;
        string memory decodedSymbol;

        // L1 bridge didn't check if the L1 token return values with proper types for `name`/`symbol`/`decimals`
        // That's why we need to try to decode them, and if it works out, set the values as getters.

        // NOTE: Solidity doesn't have a convenient way to try to decode a value:
        // - Decode them manually, i.e. write a function that will validate that data in the correct format
        // and return decoded value and a boolean value - whether it was possible to decode.
        // - Use the standard abi.decode method, but wrap it into external call which error can be handled.
        // We use second option here.

        try ExternalDecoder.decodeString(nameBytes) returns (string memory nameString) {
            decodedName = nameString;
        } catch {
            getters.ignoreName = true;
        }

        try ExternalDecoder.decodeString(symbolBytes) returns (string memory symbolString) {
            decodedSymbol = symbolString;
        } catch {
            getters.ignoreSymbol = true;
        }

        // Set decoded values for name and symbol.
        __ERC20_init_unchained(decodedName, decodedSymbol);

        try ExternalDecoder.decodeUint8(decimalsBytes) returns (uint8 decimalsUint8) {
            // Set decoded value for decimals.
            decimals_ = decimalsUint8;
        } catch {
            getters.ignoreDecimals = true;
        }

        availableGetters = getters;
        emit BridgeInitialization(_l1Address, decodedName, decodedSymbol, decimals_);
    }

    modifier onlyBridge() {
        require(msg.sender == l2Bridge);
        _;
    }

    /// @dev Mint tokens to a given account.
    /// @notice Should be called by bridge after depositing tokens from L1.
    function bridgeMint(address _to, uint256 _amount) external override onlyBridge {
        _mint(_to, _amount);
        emit BridgeMint(_to, _amount);
    }

    /// @dev Burn tokens from a given account.
    /// @notice Should be called by bridge before withdrawing tokens to L1.
    function bridgeBurn(address _from, uint256 _amount) external override onlyBridge {
        _burn(_from, _amount);
        emit BridgeBurn(_from, _amount);
    }

    function name() public view override returns (string memory) {
        // If method is not available, behave like a token that does not implement this method - revert on call.
        if (availableGetters.ignoreName) revert();
        return super.name();
    }

    function symbol() public view override returns (string memory) {
        // If method is not available, behave like a token that does not implement this method - revert on call.
        if (availableGetters.ignoreSymbol) revert();
        return super.symbol();
    }

    function decimals() public view override returns (uint8) {
        // If method is not available, behave like a token that does not implement this method - revert on call.
        if (availableGetters.ignoreDecimals) revert();
        return decimals_;
    }
}

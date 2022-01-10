pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0


/**
 * @dev Interface of the zkSync L2 protocol.
 * Note that this does **not** represent an actual Ethereum smart contract,
 * it's the definition of function signatures according to which zkSync Web3 API
 * expects the contents of `eth_sendRawTransaction` to be encoded.
 */
interface IZkSyncL2Proto {
    /**
     * @dev Common data that is passed together with every transaction.
     */
    struct CommonData {
        uint32 nonce;
        uint64 validFrom;
        uint64 validTo;
        address feeToken;
        uint256 fee;
        address initiator;
        bytes1[65] signature;
    }

    /**
     * @dev Data for the DeployContract L2 transaction.
     */
    struct DeployContract {
        bytes bytecode;
        // Calldata which describes the call to the constructor
        bytes callData;
    }

    /**
     * @dev Data for the Execute L2 transaction.
     */
    struct Execute {
        address contractAddress;
        bytes callData;
    }

    /**
     * @dev Data for the Transfer L2 transaction.
     */
    struct Transfer {
        address token;
        uint256 amount;
        address to;
    }

    /**
     * @dev Data for the Withdraw L2 transaction.
     */
    struct Withdraw {
        address token;
        uint256 amount;
        address to;
    }

    /**
     * @dev Data for the MigrateToPorter L2 transaction.
     */
    struct MigrateToPorter {
        address accountAddress;
    }

    function deployContract(DeployContract calldata, CommonData calldata) external;

    function execute(Execute calldata, CommonData calldata) external;

    function transfer(Transfer calldata, CommonData calldata) external;

    function withdraw(Withdraw calldata, CommonData calldata) external;

    function migrateToPorter(MigrateToPorter calldata, CommonData calldata) external;
}

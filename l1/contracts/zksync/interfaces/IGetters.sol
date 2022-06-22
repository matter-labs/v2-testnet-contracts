pragma solidity ^0.8;

// SPDX-License-Identifier: MIT OR Apache-2.0



interface IGetters {
    function getVerifier() external view returns (address);

    function getGovernor() external view returns (address);

    function getTotalBlocksCommitted() external view returns (uint32);

    function getTotalBlocksVerified() external view returns (uint32);

    function getTotalBlocksExecuted() external view returns (uint32);

    function getTotalPriorityRequests() external view returns (uint64);

    function isValidator(address _address) external view returns (bool);

    // Diamond Loupe

    struct Facet {
        address addr;
        bytes4[] selectors;
    }

    struct SelectorExtended {
        bytes4 selector;
        bool isFreezable;
    }

    struct FacetExtended {
        address addr;
        SelectorExtended[] selectors;
    }

    function isFunctionFreezable(bytes4 _selector) external view returns (bool);

    function facetAddress(bytes4 _selector) external view returns (address facet);

    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory);

    function facets() external view returns (Facet[] memory);

    function facetsExtended() external view returns (FacetExtended[] memory);

    function facetAddresses() external view returns (address[] memory facets);

    function l2LogsRootHash(uint32 blockNumber) external view returns (bytes32 hash);
}

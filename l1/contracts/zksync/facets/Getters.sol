// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "./Base.sol";
import "../libraries/Diamond.sol";
import "../interfaces/IGetters.sol";

/// @title Getters Contract implements functions for getting contract state from outside the blockchain.
/// @author Matter Labs
contract GettersFacet is Base, IGetters {
    function getVerifier() external view returns (address) {
        return address(s.verifier);
    }

    function getGovernor() external view returns (address) {
        return address(s.networkGovernor);
    }

    function getTotalBlocksCommitted() external view returns (uint32) {
        return s.totalBlocksCommitted;
    }

    function getTotalBlocksVerified() external view returns (uint32) {
        return s.totalBlocksVerified;
    }

    function getTotalBlocksExecuted() external view returns (uint32) {
        return s.totalBlocksExecuted;
    }

    function getTotalPriorityRequests() external view returns (uint64) {
        return s.totalPriorityRequests;
    }

    function isValidator(address _address) external view returns (bool) {
        return s.validators[_address];
    }

    // Diamond Loupe

    function isFunctionFreezable(bytes4 _selector) external view returns (bool) {
        Diamond.DiamondStorage storage ds = Diamond.getDiamondStorage();
        return ds.selectorToFacet[_selector].isFreezable;
    }

    function facetAddress(bytes4 _selector) external view returns (address) {
        Diamond.DiamondStorage storage ds = Diamond.getDiamondStorage();
        return ds.selectorToFacet[_selector].facetAddress;
    }

    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory) {
        Diamond.DiamondStorage storage ds = Diamond.getDiamondStorage();
        return ds.facetToSelectors[_facet].selectors;
    }

    function facets() external view returns (Facet[] memory result) {
        Diamond.DiamondStorage storage ds = Diamond.getDiamondStorage();

        uint256 facetsLen = ds.facets.length;
        result = new Facet[](facetsLen);

        for (uint256 i = 0; i < facetsLen; ++i) {
            address facetAddr = ds.facets[i];
            Diamond.FacetToSelectors memory facetToSelectors = ds.facetToSelectors[facetAddr];

            result[i] = Facet(facetAddr, facetToSelectors.selectors);
        }
    }

    function facetsExtended() external view returns (FacetExtended[] memory result) {
        Diamond.DiamondStorage storage ds = Diamond.getDiamondStorage();

        uint256 facetsLen = ds.facets.length;
        result = new FacetExtended[](facetsLen);

        for (uint256 i = 0; i < facetsLen; ++i) {
            address facetAddr = ds.facets[i];
            bytes4[] memory selectors = ds.facetToSelectors[facetAddr].selectors;

            uint256 selectorsLen = selectors.length;
            SelectorExtended[] memory selectorsExt = new SelectorExtended[](selectorsLen);

            for (uint256 j = 0; j < selectorsLen; ++j) {
                bytes4 selector = selectors[j];
                bool isFreezable = ds.selectorToFacet[selector].isFreezable;

                selectorsExt[j] = SelectorExtended(selector, isFreezable);
            }

            result[i] = FacetExtended(facetAddr, selectorsExt);
        }
    }

    function facetAddresses() external view returns (address[] memory) {
        Diamond.DiamondStorage storage ds = Diamond.getDiamondStorage();
        return ds.facets;
    }

    function l2LogsRootHash(uint32 _blockNumber) external view returns (bytes32) {
        return s.l2LogsRootHashes[_blockNumber];
    }
}

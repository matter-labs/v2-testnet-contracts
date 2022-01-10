pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED



import "../../libraries/Diamond.sol";
import "../../facets/Base.sol";

contract DummyFacet is Base {
    function getFacet(bytes4 _selector) external view returns (Diamond.Facet memory) {
        Diamond.DiamondStorage storage diamondStorage = Diamond.getDiamondStorage();
        return diamondStorage.selectorsToFacet[_selector];
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: UNLICENSED



import "../../libraries/Diamond.sol";

contract DiamondCutTest {
    function diamondCut(Diamond.DiamondCutData memory _diamondCut) external {
        Diamond.diamondCut(_diamondCut);
    }

    function getFacet(bytes4 _selector) external view returns (Diamond.Facet memory) {
        Diamond.DiamondStorage storage diamondStorage = Diamond.getDiamondStorage();
        return diamondStorage.selectorsToFacet[_selector];
    }
}

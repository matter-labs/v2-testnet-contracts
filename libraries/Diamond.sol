pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "./Utils.sol";

library Diamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    /// @param addr facet address
    /// @param isFreezable denotes whether this facet can be freezed
    struct Facet {
        address addr;
        bool isFreezable;
    }

    struct DiamondStorage {
        mapping(bytes4 => Facet) selectorsToFacet;
        bool isFreezed;
    }

    function getDiamondStorage() internal pure returns (DiamondStorage storage diamondStorage) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            diamondStorage.slot := position
        }
    }

    enum Action {
        Add,
        Replace,
        Remove
    }

    struct FacetCut {
        address facet;
        Action action;
        bool isFreezable;
        bytes4[] selectors;
    }

    struct DiamondCutData {
        FacetCut[] facetCuts;
        address initAddress;
        bytes initCalldata;
    }

    function diamondCut(DiamondCutData memory _diamondCut) internal {
        FacetCut[] memory facetCuts = _diamondCut.facetCuts;
        address initAddress = _diamondCut.initAddress;
        bytes memory initCalldata = _diamondCut.initCalldata;
        for (uint256 i = 0; i < facetCuts.length; ++i) {
            Diamond.Facet memory facet = Diamond.Facet({
                addr: facetCuts[i].facet,
                isFreezable: facetCuts[i].isFreezable
            });
            Action action = facetCuts[i].action;
            bytes4[] memory selectors = facetCuts[i].selectors;

            require(selectors.length > 0, "B"); // no functions for diamond cut

            if (action == Action.Add) {
                _addFunctions(facet, selectors);
            } else if (action == Action.Replace) {
                _replaceFunctions(facet, selectors);
            } else if (action == Action.Remove) {
                _removeFunctions(facet, selectors);
            } else {
                revert("C"); // undefined diamond cut action
            }
        }

        _initializeDiamondCut(initAddress, initCalldata);
        emit DiamondCut(facetCuts, initAddress, initCalldata);
    }

    event DiamondCut(FacetCut[] facetCuts, address initAddress, bytes initCalldata);

    function _addFunctions(Diamond.Facet memory _facet, bytes4[] memory _selectors) private {
        require(_facet.addr != address(0), "G"); // facet with zero address cannot be added
        Diamond.DiamondStorage storage diamondStorage = Diamond.getDiamondStorage();
        for (uint256 i = 0; i < _selectors.length; ++i) {
            bytes4 selector = _selectors[i];
            Diamond.Facet memory oldFacet = diamondStorage.selectorsToFacet[selector];
            require(oldFacet.addr == address(0), "J"); // facet for this selector already exists

            diamondStorage.selectorsToFacet[selector] = _facet;
        }
    }

    function _replaceFunctions(Diamond.Facet memory _facet, bytes4[] memory _selectors) private {
        require(_facet.addr != address(0), "K"); // cannot replace facet with zero address
        Diamond.DiamondStorage storage diamondStorage = Diamond.getDiamondStorage();
        for (uint256 i = 0; i < _selectors.length; ++i) {
            bytes4 selector = _selectors[i];
            Diamond.Facet memory oldFacet = diamondStorage.selectorsToFacet[selector];
            require(oldFacet.addr != address(0), "L"); // it is impossible to replace the facet with zero address

            diamondStorage.selectorsToFacet[selector] = _facet;
        }
    }

    function _removeFunctions(Diamond.Facet memory _facet, bytes4[] memory _selectors) private {
        require(_facet.addr == address(0), "a1"); // facet address must be zero
        require(!_facet.isFreezable, "q3"); // facet should be unfreezable
        Diamond.DiamondStorage storage diamondStorage = Diamond.getDiamondStorage();
        for (uint256 i = 0; i < _selectors.length; ++i) {
            bytes4 selector = _selectors[i];
            Diamond.Facet memory oldFacet = diamondStorage.selectorsToFacet[selector];
            require(oldFacet.addr != address(0), "a2"); // Can't delete a non-existent facet

            diamondStorage.selectorsToFacet[selector] = _facet;
        }
    }

    function _initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            require(_calldata.length == 0, "H"); // Non-empty calldata for zero address
        } else {
            require(_init == address(this) || Utils.isContract(_init), "g2"); // init address is not a contract

            (bool success, ) = _init.delegatecall(_calldata);
            require(success, "I"); // delegatecall failed
        }
    }
}

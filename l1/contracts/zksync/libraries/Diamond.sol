// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Utils.sol";

library Diamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    /// @dev Utility struct that contains associated facet & meta information of selector
    /// @param facetAddress address of the facet which is connected with selector
    /// @param selectorPosition index in `FacetToSelectors.selectors` array, where is selector stored
    /// @param isFreezable denotes whether the selector can be freezed
    struct SelectorToFacet {
        address facetAddress;
        uint16 selectorPosition;
        bool isFreezable;
    }

    /// @dev Utility struct that contains associated selectors & meta information of facet
    /// @param selectors list of all selectors that belongs to the facet
    /// @param facetPosition index in `DiamondStorage.facets` array, where is facet stored
    struct FacetToSelectors {
        bytes4[] selectors;
        uint16 facetPosition;
    }

    struct DiamondStorage {
        mapping(bytes4 => SelectorToFacet) selectorToFacet;
        mapping(address => FacetToSelectors) facetToSelectors;
        address[] facets;
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
            Action action = facetCuts[i].action;
            address facet = facetCuts[i].facet;
            bool isFreezable = facetCuts[i].isFreezable;
            bytes4[] memory selectors = facetCuts[i].selectors;

            require(selectors.length > 0, "B"); // no functions for diamond cut

            if (action == Action.Add) {
                _addFunctions(facet, selectors, isFreezable);
            } else if (action == Action.Replace) {
                _replaceFunctions(facet, selectors, isFreezable);
            } else if (action == Action.Remove) {
                _removeFunctions(facet, selectors, isFreezable);
            } else {
                revert("C"); // undefined diamond cut action
            }
        }

        _initializeDiamondCut(initAddress, initCalldata);
        emit DiamondCut(facetCuts, initAddress, initCalldata);
    }

    event DiamondCut(FacetCut[] facetCuts, address initAddress, bytes initCalldata);

    /// @dev Add new functions to the diamond proxy
    /// NOTE: expect but NOT enforce that `_selectors` is NON-EMPTY array
    function _addFunctions(
        address _facet,
        bytes4[] memory _selectors,
        bool _isFreezable
    ) private {
        DiamondStorage storage ds = getDiamondStorage();

        require(_facet != address(0), "G"); // facet with zero address cannot be added

        // Add facet to the list of facets if the facet address is new one
        _saveFacetIfNew(_facet);

        for (uint256 i = 0; i < _selectors.length; ++i) {
            bytes4 selector = _selectors[i];
            SelectorToFacet memory oldFacet = ds.selectorToFacet[selector];
            require(oldFacet.facetAddress == address(0), "J"); // facet for this selector already exists

            _addOneFunction(_facet, selector, _isFreezable);
        }
    }

    /// @dev Change associated facets to alredy known function selectors
    /// NOTE: expect but NOT enforce that `_selectors` is NON-EMPTY array
    function _replaceFunctions(
        address _facet,
        bytes4[] memory _selectors,
        bool _isFreezable
    ) private {
        DiamondStorage storage ds = getDiamondStorage();

        require(_facet != address(0), "K"); // cannot replace facet with zero address

        // Add facet to the list of facets if the facet address is new one
        _saveFacetIfNew(_facet);

        for (uint256 i = 0; i < _selectors.length; ++i) {
            bytes4 selector = _selectors[i];
            SelectorToFacet memory oldFacet = ds.selectorToFacet[selector];
            require(oldFacet.facetAddress != address(0), "L"); // it is impossible to replace the facet with zero address

            _removeOneFunction(oldFacet.facetAddress, selector);
            _addOneFunction(_facet, selector, _isFreezable);
        }
    }

    /// @dev Remove assocition with function and facet
    /// NOTE: expect but NOT enforce that `_selectors` is NON-EMPTY array
    function _removeFunctions(
        address _facet,
        bytes4[] memory _selectors,
        bool _isFreezable
    ) private {
        DiamondStorage storage ds = getDiamondStorage();

        require(_facet == address(0), "a1"); // facet address must be zero
        require(!_isFreezable, "q3"); // facet should be unfreezable

        for (uint256 i = 0; i < _selectors.length; ++i) {
            bytes4 selector = _selectors[i];
            SelectorToFacet memory oldFacet = ds.selectorToFacet[selector];
            require(oldFacet.facetAddress != address(0), "a2"); // Can't delete a non-existent facet

            _removeOneFunction(oldFacet.facetAddress, selector);
        }
    }

    /// @dev Add address to the list of known facets if address not on the list yet
    /// NOTE: should be called ONLY before adding new selector associated with the address
    function _saveFacetIfNew(address _facet) private {
        DiamondStorage storage ds = getDiamondStorage();

        uint16 selectorsLength = uint16(ds.facetToSelectors[_facet].selectors.length);
        // If there are no selectors associated with facet then save facet as new one
        if (selectorsLength == 0) {
            ds.facetToSelectors[_facet].facetPosition = uint16(ds.facets.length);
            ds.facets.push(_facet);
        }
    }

    /// @dev Add one function to the already known facet
    /// NOTE: It is expected but NOT enforced that:
    /// - `_facet` is NON-ZERO address
    /// - `_facet` is already stored address in `DiamondStorage.facets`
    /// - `_selector` is NOT associated by another facet
    function _addOneFunction(
        address _facet,
        bytes4 _selector,
        bool _isFreezable
    ) private {
        DiamondStorage storage ds = getDiamondStorage();

        uint16 selectorPosition = uint16(ds.facetToSelectors[_facet].selectors.length);
        ds.selectorToFacet[_selector] = SelectorToFacet({
            facetAddress: _facet,
            selectorPosition: selectorPosition,
            isFreezable: _isFreezable
        });
        ds.facetToSelectors[_facet].selectors.push(_selector);
    }

    /// @dev Remove one associated function with facet
    /// NOTE: It is expected but NOT enforced that `_facet` is NON-ZERO address
    function _removeOneFunction(address _facet, bytes4 _selector) private {
        DiamondStorage storage ds = getDiamondStorage();

        // Get index of `FacetToSelectors.selectors` of the selector and last element of array
        uint256 selectorPosition = ds.selectorToFacet[_selector].selectorPosition;
        uint256 lastSelectorPosition = ds.facetToSelectors[_facet].selectors.length - 1;

        // If the selector is not at the end of the array then move the last element to the selector position
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetToSelectors[_facet].selectors[lastSelectorPosition];

            ds.facetToSelectors[_facet].selectors[selectorPosition] = lastSelector;
            ds.selectorToFacet[lastSelector].selectorPosition = uint16(selectorPosition);
        }

        // Remove last element from the selectors array
        ds.facetToSelectors[_facet].selectors.pop();

        // Finally, clean up the association with facet
        delete ds.selectorToFacet[_selector];

        // If there are no selectors for facet then remove the facet from the list of known facets
        if (lastSelectorPosition == 0) {
            _removeFacet(_facet);
        }
    }

    /// @dev remove facet from the list of known facets
    /// NOTE: It is expected but NOT enforced that there are no selectors associated wih `_facet`
    function _removeFacet(address _facet) private {
        DiamondStorage storage ds = getDiamondStorage();

        // Get index of `DiamondStorage.facets` of the facet and last element of array
        uint256 facetPosition = ds.facetToSelectors[_facet].facetPosition;
        uint256 lastFacetPosition = ds.facets.length - 1;

        // If the facet is not at the end of the array then move the last element to the facet position
        if (facetPosition != lastFacetPosition) {
            address lastFacet = ds.facets[lastFacetPosition];

            ds.facets[facetPosition] = lastFacet;
            ds.facetToSelectors[lastFacet].facetPosition = uint16(facetPosition);
        }

        // Remove last element from the facets array
        ds.facets.pop();

        // Remove only `facetPosition` and EXPECT that `selectors` is already empty
        delete ds.facetToSelectors[_facet].facetPosition;
    }

    function _initializeDiamondCut(address _init, bytes memory _calldata) private {
        if (_init == address(0)) {
            require(_calldata.length == 0, "H"); // Non-empty calldata for zero address
        } else {
            require(_init == address(this) || Utils.isContract(_init), "g2"); // init address is not a contract

            (bool success, ) = _init.delegatecall(_calldata);
            require(success, "I"); // delegatecall failed
        }
    }
}

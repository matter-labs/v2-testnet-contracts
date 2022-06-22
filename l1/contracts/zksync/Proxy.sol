pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT OR Apache-2.0



import "./libraries/Diamond.sol";

/// @title Diamond Proxy Cotract (EIP-2535)
/// @author Matter Labs
contract Proxy {
    constructor(Diamond.DiamondCutData memory _diamondCut) {
        Diamond.diamondCut(_diamondCut);
    }

    /// @dev Find facet for function that is called and execute the
    /// function if a facet is found and return any value
    fallback() external payable {
        Diamond.DiamondStorage storage diamondStorage = Diamond.getDiamondStorage();
        // get facet from function selector
        Diamond.SelectorToFacet memory facet = diamondStorage.selectorToFacet[msg.sig];
        address facetAddress = facet.facetAddress;

        require(facetAddress != address(0), "F"); // Proxy has no facet for this selector
        require(!diamondStorage.isFreezed || !facet.isFreezable, "q1"); // Facet is freezed

        assembly {
            // The pointer to the free memory slot
            let ptr := mload(0x40)
            // Copy function signature and arguments from calldata at zero position into memory at pointer position
            calldatacopy(ptr, 0, calldatasize())
            // Delegatecall method of the implementation contract, returns 0 on error
            let result := delegatecall(gas(), facetAddress, ptr, calldatasize(), 0, 0)
            // Get the size of the last return data
            let size := returndatasize()
            // Copy the size length of bytes from return data at zero position to pointer position
            returndatacopy(ptr, 0, size)
            // Depending on result value
            switch result
            case 0 {
                // End execution and revert state changes
                revert(ptr, size)
            }
            default {
                // Return data with length of size at pointers position
                return(ptr, size)
            }
        }
    }
}

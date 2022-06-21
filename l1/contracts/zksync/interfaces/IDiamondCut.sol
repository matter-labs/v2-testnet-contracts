// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8;

import "../libraries/Diamond.sol";

interface IDiamondCut {
    function proposeDiamondCut(Diamond.FacetCut[] calldata _facetCuts, address _initAddress) external;

    function cancelDiamondCutProposal() external;

    function executeDiamondCutProposal(Diamond.DiamondCutData calldata _diamondCut) external;

    function emergencyFreezeDiamond() external;

    function unfreezeDiamond() external;

    function approveEmergencyDiamondCutAsSecurityCouncilMember(bytes32 _diamondCutHash) external;

    // FIXME: token holders should have an ability to cancel upgrade

    event DiamondCutProposal(Diamond.FacetCut[] _facetCuts, address _initAddress);

    event DiamondCutProposalCancelation();

    event DiamondCutProposalExecution(Diamond.DiamondCutData _diamondCut);

    event EmergencyFreeze();

    event Unfreeze();

    event EmergencyDiamondCutApproved(address _address);
}

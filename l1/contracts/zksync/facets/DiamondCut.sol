// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IDiamondCut.sol";
import "../libraries/Diamond.sol";
import "../Config.sol";
import "./Base.sol";

/// @title DiamondCut contract responsible for the management of upgrades.
/// @author Matter Labs
contract DiamondCutFacet is Base, IDiamondCut {
    function proposeDiamondCut(Diamond.FacetCut[] calldata _facetCuts, address _initAddress) external {
        _requireGovernor(msg.sender);

        require(s.diamondCutStorage.proposedDiamondCutTimestamp == 0, "a3"); // proposal already exists

        s.diamondCutStorage.proposedDiamondCutHash = keccak256(abi.encode(_facetCuts, _initAddress));
        s.diamondCutStorage.proposedDiamondCutTimestamp = block.timestamp;
        s.diamondCutStorage.currentProposalId += 1;

        emit DiamondCutProposal(_facetCuts, _initAddress);
    }

    function cancelDiamondCutProposal() external {
        _requireGovernor(msg.sender);

        require(_cancelDiamondCutProposal(), "g1"); // failed cancel diamond cut
    }

    function executeDiamondCutProposal(Diamond.DiamondCutData calldata _diamondCut) external {
        _requireGovernor(msg.sender);

        Diamond.DiamondStorage storage diamondStorage = Diamond.getDiamondStorage();
        require(
            !diamondStorage.isFreezed ||
                s.diamondCutStorage.securityCouncilEmergencyApprovals >=
                SECURITY_COUNCIL_APPROVALS_FOR_EMERGENCY_UPGRADE,
            "f3"
        ); // should not be freezed or should have enough security council approvals

        require(
            s.diamondCutStorage.proposedDiamondCutHash ==
                keccak256(abi.encode(_diamondCut.facetCuts, _diamondCut.initAddress)),
            "a4"
        ); // proposal should be created
        require(_cancelDiamondCutProposal(), "a5"); // failed cancel proposal
        require(block.timestamp >= s.diamondCutStorage.proposedDiamondCutTimestamp + UPGRADE_NOTICE_PERIOD, "a6"); // notice period should expired

        Diamond.diamondCut(_diamondCut);

        emit DiamondCutProposalExecution(_diamondCut);

        if (diamondStorage.isFreezed) {
            diamondStorage.isFreezed = false;
            emit Unfreeze();
        }
    }

    function emergencyFreezeDiamond() external {
        _requireGovernor(msg.sender);

        Diamond.DiamondStorage storage diamondStorage = Diamond.getDiamondStorage();
        bool canFreeze = block.timestamp >=
            s.diamondCutStorage.lastDiamondFreezeTimestamp + DELAY_BETWEEN_DIAMOND_FREEZES;
        require(canFreeze && !diamondStorage.isFreezed, "a7"); // not enough time has passed since the previous freeze
        _cancelDiamondCutProposal();

        diamondStorage.isFreezed = true;
        s.diamondCutStorage.lastDiamondFreezeTimestamp = block.timestamp;

        emit EmergencyFreeze();
    }

    function unfreezeDiamond() external {
        Diamond.DiamondStorage storage diamondStorage = Diamond.getDiamondStorage();
        bool canUnfreeze = block.timestamp >= s.diamondCutStorage.lastDiamondFreezeTimestamp + MIN_DIAMOND_FREEZE_TIME;
        require(canUnfreeze && diamondStorage.isFreezed, "a7"); // not enough time has passed freeze

        require(
            _isGovernor(msg.sender) ||
                block.timestamp >= s.diamondCutStorage.lastDiamondFreezeTimestamp + MAX_DIAMOND_FREEZE_TIME,
            "a8"
        ); // caller must be a governor or enough time have benn passed
        _cancelDiamondCutProposal();

        diamondStorage.isFreezed = false;

        emit Unfreeze();
    }

    function approveEmergencyDiamondCutAsSecurityCouncilMember(bytes32 _diamondCutHash) external {
        require(s.diamondCutStorage.securityCouncilMembers[msg.sender], "a9"); // not a security council member
        require(
            s.diamondCutStorage.securityCouncilMemberLastApprovedProposalId[msg.sender] <
                s.diamondCutStorage.currentProposalId,
            "ao"
        ); // already approved this proposal
        s.diamondCutStorage.securityCouncilMemberLastApprovedProposalId[msg.sender] = s
            .diamondCutStorage
            .currentProposalId;

        Diamond.DiamondStorage storage diamondStorage = Diamond.getDiamondStorage();
        require(s.diamondCutStorage.proposedDiamondCutTimestamp != 0 && diamondStorage.isFreezed, "f0"); // there is no proposed diamond cut on freeze
        require(s.diamondCutStorage.proposedDiamondCutHash == _diamondCutHash, "f1"); // proposed diamond cut do not matches to the approved
        s.diamondCutStorage.securityCouncilEmergencyApprovals++;

        emit EmergencyDiamondCutApproved(msg.sender);
    }

    function _cancelDiamondCutProposal() internal returns (bool) {
        if (s.diamondCutStorage.proposedDiamondCutTimestamp == 0) {
            return false;
        }

        s.diamondCutStorage.proposedDiamondCutHash = bytes32(0);
        s.diamondCutStorage.proposedDiamondCutTimestamp = 0;
        s.diamondCutStorage.securityCouncilEmergencyApprovals = 0;

        emit DiamondCutProposalCancelation();

        return true;
    }
}

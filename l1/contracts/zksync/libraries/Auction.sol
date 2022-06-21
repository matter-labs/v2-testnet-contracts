// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "../Storage.sol";
import "../Config.sol";
import "./WithdrawalHelper.sol";

/// @author Matter Labs
library Auction {
    /// @param creator Address that was committed for current bid
    /// @param bidAmount Pledge that the creator left
    /// @param complexityRoot Complexity root of the operations performed on which the creator of the bet is committed
    struct Bid {
        address creator;
        uint96 bidAmount;
        uint112 complexityRoot;
    }

    /// @notice Returns a value that indicates the priority of the bet
    function significance(Bid memory _self) internal pure returns (uint256 value) {
        // It is safe because the maximum value of `bidAmount` is type(uint96).max and the max value of `complexityRoot` is type(uint112).max
        unchecked {
            value = uint256(_self.bidAmount) * uint256(_self.complexityRoot);
        }
    }

    /// @notice replaces the bid with a new one and if need return funds to the owner of the previous bid
    /// @param _newAuctionBid bid that should become the current max auction bid
    /// @param _refundPledge indicates whether need to return the funds to the owner of the previous bid
    function replaceBid(
        AppStorage storage s,
        Bid memory _newAuctionBid,
        bool _refundPledge
    ) internal {
        Bid memory previousMaxAuctionBid = s.currentMaxAuctionBid;

        if (previousMaxAuctionBid.bidAmount != 0) {
            // Refunds money only when requested and the balance is not zero
            if (_refundPledge) {
                address payable recipient = payable(previousMaxAuctionBid.creator);
                bool sent = WithdrawalHelper.sendETHNoRevert(
                    recipient,
                    uint256(previousMaxAuctionBid.bidAmount),
                    WITHDRAWAL_GAS_LIMIT
                );

                if (!sent) {
                    unchecked {
                        s.pendingBalances[recipient] += uint256(previousMaxAuctionBid.bidAmount);
                    }
                }
            } else {
                // Burn pledge of don't need to return it
                unchecked {
                    s.pendingBalances[address(0)] += uint256(previousMaxAuctionBid.bidAmount);
                }
            }
        }

        s.currentMaxAuctionBid = _newAuctionBid;
    }
}

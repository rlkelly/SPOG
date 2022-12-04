// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAuction {
    struct AuctionData {
        uint256 startTime;
        uint256 currentBid;
        address currentBidder;
        bool finalized;
        uint256 tokenAmount;
    }
}

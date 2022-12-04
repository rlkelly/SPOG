// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAuction {
    struct AuctionData {
        uint startTime;
        uint currentBid;
        address currentBidder;
        bool finalized;
        uint tokenAmount;
    }
}

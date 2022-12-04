// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IAuction} from "./interfaces/IAuction.sol";

abstract contract Auction is ReentrancyGuard, IAuction, IERC20 {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    Counters.Counter private _auctionId;
    mapping(uint256 => AuctionData) public auctionData;

    function _createAuction(uint256 id, uint256 _tokenAmount) internal {
        require(auctionData[id].startTime == 0, "Auction already created");
        auctionData[id] = AuctionData({
            startTime: block.timestamp,
            currentBid: 0,
            currentBidder: address(0),
            finalized: false,
            tokenAmount: _tokenAmount
        });
    }

    function bid(uint256 id, uint256 amount) external {
        require(
            auctionData[id].startTime + time() > block.timestamp,
            "auction ended"
        );
        auctionData[id].currentBid = amount;
        auctionData[id].currentBidder = msg.sender;

        if (auctionData[id].currentBidder != address(0)) {
            token().transfer(
                auctionData[id].currentBidder,
                auctionData[id].currentBid
            );
        }
        token().transferFrom(msg.sender, address(this), amount);
    }

    function finalize(uint256 id) external nonReentrant {
        require(
            auctionData[id].startTime + time() <= block.timestamp,
            "auction still running"
        );
        require(!auctionData[id].finalized, "auction finalized");

        auctionData[id].finalized = true;
        this.transfer(
            auctionData[id].currentBidder,
            auctionData[id].tokenAmount
        );
    }

    function time() public view virtual returns (uint256);

    function token() public view virtual returns (IERC20);
}

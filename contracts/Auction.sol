// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAuction} from "./interfaces/IAuction.sol";

abstract contract Auction is IAuction, IERC20 {
	using SafeERC20 for IERC20;
	using Counters for Counters.Counter;

	Counters.Counter private _auctionId;
	mapping(uint => AuctionData) public auctionData;

    function _createAuction(uint id, uint _tokenAmount) internal {
        require(auctionData[id].startTime == 0, "Auction already created");
        auctionData[id] = AuctionData({
            startTime: block.timestamp,
            currentBid: 0,
            currentBidder: address(0),
            finalized: false,
            tokenAmount: _tokenAmount
        });
    }

    function bid(uint id, uint amount) external {
        require(auctionData[id].startTime + time() > block.timestamp,
            "auction ended");

        if (auctionData[id].currentBidder != address(0)) {
            token().transfer(auctionData[id].currentBidder, auctionData[id].currentBid);
        }
        token().transferFrom(msg.sender, address(this), amount);

        auctionData[id].currentBid = amount;
        auctionData[id].currentBidder = msg.sender;
    }

    function finalize(uint id) external {
        require(auctionData[id].startTime + time() <= block.timestamp,
            "auction still running");
        require(!auctionData[id].finalized, "auction finalized");

        auctionData[id].finalized = true;
        this.transfer(auctionData[id].currentBidder, auctionData[id].tokenAmount);
    }

    function time() public view virtual returns(uint);
    function token() public view virtual returns(IERC20);
}

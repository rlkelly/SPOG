// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ERC20Snapshot, ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IGrief} from "./interfaces/IGrief.sol";
import "hardhat/console.sol";

abstract contract Grief is ERC20Snapshot, IGrief {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    IERC20 internal immutable TOKEN;
    IERC20 internal immutable CASH;
    uint256 internal immutable TAX;
    uint256 internal immutable TIME;
    uint256 internal immutable INFLATOR; // 10000 = 100%

    Counters.Counter internal _voteId;
    mapping(uint256 => VoteData) public voteData;
    uint256 public latestGriefStartTime;
    uint256 public latestGriefId;

    event GriefCreated(uint256 voteId);

    constructor(
        IERC20 _token,
        IERC20 _cash,
        uint256 _tax,
        uint256 _time,
        uint256 _inflator
    ) {
        TOKEN = _token;
        CASH = _cash;
        TAX = _tax;
        TIME = _time;
        INFLATOR = _inflator;

        // no grief for first period
        latestGriefStartTime = block.timestamp;
    }

    function grief() external {
        uint256 snapshotId = _snapshot();
        require(
            latestGriefStartTime < block.timestamp - TIME,
            "still in grief period"
        );

        uint256 currentVoteId = _voteId.current();

        latestGriefId = currentVoteId;
        voteData[currentVoteId].snapshotId = snapshotId;
        voteData[currentVoteId].startTime = block.timestamp;
        voteData[currentVoteId].isGrief = true;
        latestGriefStartTime = block.timestamp;
        voteData[currentVoteId].remainingTokenAmount =
            (totalSupply() * INFLATOR) /
            10000;
        voteData[currentVoteId].inflationTotal = voteData[currentVoteId]
            .remainingTokenAmount;

        emit GriefCreated(latestGriefId);
        _mint(address(this), voteData[currentVoteId].remainingTokenAmount);

        _voteId.increment();
    }
}

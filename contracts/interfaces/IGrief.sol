// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IGrief {
    struct VoteData {
        Invocation invocation;
        VoteOutcome outcome;
        uint256 snapshotId;
        uint256 startTime;
        uint256 inflationTotal;
        uint256 remainingTokenAmount;
        bool isGrief;
        bool finalized;
        bool merged;
    }

    struct Invocation {
        address target;
        bytes callData;
    }

    struct VoteOutcome {
        uint128 yay;
        uint128 nay;
    }
}

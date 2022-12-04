// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IGrief {
    struct VoteData {
        Invocation invocation;
        VoteOutcome outcome;
        uint snapshotId;
        uint startTime;
        uint inflationTotal;
        uint remainingTokenAmount;
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

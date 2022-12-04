// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IBuyout {
    struct Buyout {
        uint256 startTime;
        uint256 snapshotId;
        uint256 competingPoolBalance;
        uint256 originalPoolBalance;
        address transferTarget;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IBuyout {
    struct Buyout {
        uint startTime;
        uint snapshotId;
        uint competingPoolBalance;
        uint originalPoolBalance;
        address transferTarget;
    }
}

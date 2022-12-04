// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IGrief} from "./IGrief.sol";

interface ISPOG is IGrief {
    function stake(uint256 amount) external;

    function claim(uint256 voteId) external;

    function vote(uint256 voteId, bool affirmative) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IGrief} from "./IGrief.sol";

interface ISPOG is IGrief {
    function stake(uint amount) external;
    function claim(uint voteId) external;
    function vote(uint voteId, bool affirmative) external;
}

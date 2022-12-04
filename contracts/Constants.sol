// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// NOT USED
library Constants {
    IERC20 public constant TOKEN = IERC20(address(0x0));
    uint256 public constant TAX = 100 ether;
    uint256 public constant TIME = 2 weeks;
    uint256 public constant INFLATOR = 500;
}

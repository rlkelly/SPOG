// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Buyout {
    using SafeERC20 for IERC20;

    function buyout() public {
        token().safeTransferFrom(msg.sender, address(this), tax());
        // TODO: figure out how to start a runoff
    }

    function time() public view virtual returns (uint256);

    function token() public view virtual returns (IERC20);

    function tax() public view virtual returns (uint256);
}

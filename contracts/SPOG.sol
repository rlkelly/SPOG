// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Snapshot, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ISPOG} from "./interfaces/ISPOG.sol";
import {Grief} from "./Grief.sol";
import {Auction} from "./Auction.sol";
import {Buyout} from "./Buyout.sol";

contract SPOG is Auction, Grief, Buyout, ISPOG {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    uint256 private _startTime;

    mapping(uint256 => mapping(address => bool)) public votePerUser;
    mapping(uint256 => mapping(address => bool)) public claimPerUser;

    event VoteCreated(uint256 voteId, uint256 startTime);
    event Merged(uint256 voteId, bool sent, bytes data);
    event AuctionCreated(uint256 voteId, uint256 tokenAmount);

    constructor(
        string memory name,
        string memory symbol,
        IERC20 _token,
        IERC20 _cash,
        uint256 _tax,
        uint256 _time,
        uint256 _inflator
    ) Grief(_token, _cash, _tax, _time, _inflator) ERC20(name, symbol) {
        _startTime = block.timestamp;
    }

    modifier _onlyStartPeriod() {
        require(
            block.timestamp < _startTime + TIME,
            "only during staking period"
        );
        _;
    }

    function balance() public view returns (uint256) {
        return TOKEN.balanceOf(address(this));
    }

    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? 1e18 : (balance() * 1e18) / totalSupply();
    }

    function stake(uint256 _amount) external _onlyStartPeriod {
        uint256 _balance = balance();
        TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = balance();
        _amount = _after - _balance; // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / _balance;
        }
        _mint(msg.sender, shares);
    }

    function withdraw(uint256 _shares) external {
        // TODO: can you withdraw these tokens?
        uint256 r = (balance() * _shares) / totalSupply();
        _burn(msg.sender, _shares);
        TOKEN.safeTransfer(msg.sender, r);
    }

    function request(address target, bytes calldata parameters) external {
        // take snapshot for vote
        uint256 snapshotId = _snapshot();

        CASH.safeTransferFrom(msg.sender, address(this), TAX);

        uint256 _voteInflation = INFLATOR * totalSupply();
        _mint(address(this), _voteInflation);

        uint256 currentId = _voteId.current();
        _voteId.increment();

        voteData[currentId] = VoteData({
            invocation: Invocation(target, parameters),
            outcome: VoteOutcome(0, 0),
            snapshotId: snapshotId,
            startTime: block.timestamp,
            remainingTokenAmount: _voteInflation,
            inflationTotal: _voteInflation,
            isGrief: false,
            finalized: false,
            merged: false
        });

        emit VoteCreated(currentId, block.timestamp);
    }

    function vote(uint256 voteId, bool affirmative) public {
        require(!votePerUser[voteId][msg.sender], "Already voted");
        require(
            voteData[voteId].startTime + TIME > block.timestamp,
            "voting has ended"
        );

        uint256 snapshotId = voteData[voteId].snapshotId;
        uint128 userBalance = uint128(balanceOfAt(msg.sender, snapshotId));
        if (affirmative) {
            voteData[voteId].outcome.yay += userBalance;
        } else {
            voteData[voteId].outcome.nay += userBalance;
        }
        votePerUser[voteId][msg.sender] = true;

        if (voteData[voteId].isGrief && affirmative) {
            // TODO: not sure if this math works out properly
            uint256 r = Math.mulDiv(
                userBalance,
                voteData[voteId].inflationTotal,
                totalSupplyAt(snapshotId)
            );

            // remove tokens from tokenAmount if vote YES
            voteData[voteId].remainingTokenAmount -= r;
            _burn(address(this), r);
        }
    }

    function claim(uint256 voteId) public {
        require(votePerUser[voteId][msg.sender], "Didnt vote");
        require(!claimPerUser[voteId][msg.sender], "Already claimed");
        require(!voteData[voteId].finalized, "vote already finalized");
        require(!voteData[voteId].isGrief, "no claim on grief vote");

        // TODO: any need for a lockup?
        uint256 snapshotId = voteData[voteId].snapshotId;

        // TODO: not sure if this math works out properly
        uint256 r = Math.mulDiv(
            balanceOfAt(msg.sender, snapshotId),
            voteData[voteId].inflationTotal,
            totalSupplyAt(snapshotId)
        );
        _transfer(address(this), msg.sender, r);

        // remove tokens from claim
        voteData[voteId].remainingTokenAmount -= r;

        claimPerUser[voteId][msg.sender] = true;
    }

    function voteAndClaim(uint256 voteId, bool affirmative) external {
        vote(voteId, affirmative);
        claim(voteId);
    }

    function merge(uint256 voteId) external {
        require(!voteData[voteId].merged, "already merged");
        require(!voteData[voteId].isGrief, "no merge for grief");
        require(voteData[voteId].finalized, "not finalized");
        require(
            voteData[voteId].startTime + TIME * 2 >= block.timestamp,
            "expired"
        );

        Invocation memory invocation = voteData[voteId].invocation;
        // solhint-disable-next-line
        (bool _sent, bytes memory _data) = invocation.target.call(
            invocation.callData
        );
        emit Merged(voteId, _sent, _data);

        voteData[voteId].merged = true;
    }

    function sell(uint256 voteId) external {
        // starts the auction
        require(
            voteData[voteId].startTime + TIME <= block.timestamp,
            "voting still running"
        );
        require(!voteData[voteId].finalized, "voting already finalized");
        voteData[voteId].finalized = true;

        uint256 tokenAmount = voteData[voteId].remainingTokenAmount;
        if (tokenAmount > 0) {
            _createAuction(voteId, tokenAmount);
            emit AuctionCreated(voteId, tokenAmount);
            voteData[voteId].remainingTokenAmount = 0;
        } else {
            auctionData[voteId].finalized = true;
        }
    }

    // VIEWS

    function time()
        public
        view
        virtual
        override(Auction, Buyout)
        returns (uint256)
    {
        return TIME;
    }

    function token() public view override(Auction, Buyout) returns (IERC20) {
        return TOKEN;
    }

    function tax() public view override(Buyout) returns (uint256) {
        return TAX;
    }

    function inflator() public view returns (uint256) {
        return INFLATOR;
    }

    function cash() public view override returns (IERC20) {
        return CASH;
    }

    function balanceInToken(address user) public view returns (uint256) {
        // convert the shares to token units
        return (balance() * balanceOf(user)) / totalSupply();
    }
}

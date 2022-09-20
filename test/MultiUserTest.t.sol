pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract MultiUserTest is TestHelper {
    function setUp() public {
        _setUp();
    }

    function testDoubleMintMaker() public {
        _mintMaker(1 ether, 1 ether, cuh);
        _mintMaker(1 ether, 1 ether, dennis);

        bytes32 cuhPositionID = Position.getId(cuh);
        bytes32 dennisPositionID = Position.getId(dennis);

        bytes32 next;
        bytes32 previous;
        uint256 liquidity;
        uint256 tokensOwed;
        uint256 rewardPerTokenPaid;
        bool utilized;

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

        assertEq(next, dennisPositionID);
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 2 ether - 1000);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

        assertEq(next, bytes32(0));
        assertEq(previous, cuhPositionID);
        assertEq(liquidity, 2 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        assertEq(lendgine.lastPosition(), dennisPositionID);
        assertEq(lendgine.currentPosition(), cuhPositionID);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.balanceOf(address(lendgine)), 4 ether - 1000);
        assertEq(pair.balanceOf(cuh), 0 ether);
        assertEq(pair.balanceOf(dennis), 0 ether);
    }

    function testRemoveUnutilizedMaker() public {
        _mintMaker(1 ether, 1 ether, cuh);
        _mintMaker(1 ether, 1 ether, dennis);
        _burnMaker(2 ether - 1000, cuh);

        bytes32 cuhPositionID = Position.getId(cuh);
        bytes32 dennisPositionID = Position.getId(dennis);

        bytes32 next;
        bytes32 previous;
        uint256 liquidity;
        uint256 tokensOwed;
        uint256 rewardPerTokenPaid;
        bool utilized;

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

        assertEq(next, bytes32(0));
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 0 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

        assertEq(next, bytes32(0));
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 2 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        assertEq(lendgine.lastPosition(), dennisPositionID);
        assertEq(lendgine.currentPosition(), dennisPositionID);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.balanceOf(address(lendgine)), 2 ether);
        assertEq(pair.balanceOf(cuh), 2 ether - 1000);
        assertEq(pair.balanceOf(dennis), 0 ether);
    }

    function testPartialRemoveUtilizedMaker() public {
        _mintMaker(1 ether, 1 ether, cuh);
        _mintMaker(1 ether, 1 ether, dennis);
        _mint(10 ether, address(this));
        _burnMaker(1 ether - 500, cuh);

        bytes32 cuhPositionID = Position.getId(cuh);
        bytes32 dennisPositionID = Position.getId(dennis);

        bytes32 next;
        bytes32 previous;
        uint256 liquidity;
        uint256 tokensOwed;
        uint256 rewardPerTokenPaid;
        bool utilized;

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

        assertEq(next, dennisPositionID);
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 1 ether - 500);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, true);

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

        assertEq(next, bytes32(0));
        assertEq(previous, cuhPositionID);
        assertEq(liquidity, 2 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, true);

        assertEq(lendgine.lastPosition(), dennisPositionID);
        assertEq(lendgine.currentPosition(), dennisPositionID);
        assertEq(lendgine.currentLiquidity(), 500);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.balanceOf(address(this)), 1 ether);
        assertEq(pair.balanceOf(cuh), 1 ether - 500);
        assertEq(pair.balanceOf(address(lendgine)), 2 ether - 500);
        assertEq(pair.balanceOf(dennis), 0 ether);
        assertEq(pair.totalSupply(), 4 ether);
    }

    function testFullRemoveUtilizedMaker() public {
        _mintMaker(1 ether, 1 ether, cuh);
        _mintMaker(1 ether, 1 ether, dennis);
        _mint(10 ether, address(this));
        _burnMaker(2 ether - 1000, cuh);

        bytes32 cuhPositionID = Position.getId(cuh);
        bytes32 dennisPositionID = Position.getId(dennis);

        bytes32 next;
        bytes32 previous;
        uint256 liquidity;
        uint256 tokensOwed;
        uint256 rewardPerTokenPaid;
        bool utilized;

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

        assertEq(next, bytes32(0));
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 0 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

        assertEq(next, bytes32(0));
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 2 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, true);

        assertEq(lendgine.lastPosition(), dennisPositionID);
        assertEq(lendgine.currentPosition(), dennisPositionID);
        assertEq(lendgine.currentLiquidity(), 1 ether);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.balanceOf(address(this)), 1 ether);
        assertEq(pair.balanceOf(cuh), 2 ether - 1000);
        assertEq(pair.balanceOf(address(lendgine)), 1 ether);
        assertEq(pair.balanceOf(dennis), 0 ether);
        assertEq(pair.totalSupply(), 4 ether);
    }

    function testMintUnutilizedMaker() public {
        _mintMaker(1 ether, 1 ether, cuh);
        _mintMaker(1 ether, 1 ether, dennis);
        _mintMaker(1 ether, 1 ether, cuh);

        bytes32 cuhPositionID = Position.getId(cuh);
        bytes32 dennisPositionID = Position.getId(dennis);

        bytes32 next;
        bytes32 previous;
        uint256 liquidity;
        uint256 tokensOwed;
        uint256 rewardPerTokenPaid;
        bool utilized;

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

        assertEq(next, bytes32(0));
        assertEq(previous, dennisPositionID);
        assertEq(liquidity, 4 ether - 1000);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

        assertEq(next, cuhPositionID);
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 2 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        assertEq(lendgine.lastPosition(), cuhPositionID);
        assertEq(lendgine.currentPosition(), dennisPositionID);
        assertEq(lendgine.currentLiquidity(), 0 ether);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.balanceOf(address(lendgine)), 6 ether - 1000);
        assertEq(pair.balanceOf(cuh), 0 ether);
        assertEq(pair.balanceOf(dennis), 0 ether);
    }

    function testMintUtilizedMaker() public {
        _mintMaker(1 ether, 1 ether, cuh);
        _mintMaker(1 ether, 1 ether, dennis);
        _mint(10 ether, address(this));
        _mintMaker(1 ether, 1 ether, cuh);

        bytes32 cuhPositionID = Position.getId(cuh);
        bytes32 dennisPositionID = Position.getId(dennis);

        bytes32 next;
        bytes32 previous;
        uint256 liquidity;
        uint256 tokensOwed;
        uint256 rewardPerTokenPaid;
        bool utilized;

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

        assertEq(next, bytes32(0));
        assertEq(previous, dennisPositionID);
        assertEq(liquidity, 4 ether - 1000);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

        assertEq(next, cuhPositionID);
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 2 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, true);

        assertEq(lendgine.lastPosition(), cuhPositionID);
        assertEq(lendgine.currentPosition(), dennisPositionID);
        assertEq(lendgine.currentLiquidity(), 1 ether);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.balanceOf(address(this)), 1 ether);
        assertEq(pair.balanceOf(address(lendgine)), 5 ether - 1000);
        assertEq(pair.balanceOf(cuh), 0 ether);
        assertEq(pair.balanceOf(dennis), 0 ether);
    }
}

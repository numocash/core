pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { MintCallbackHelper } from "./utils/MintCallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract BurnMakerTest is MintCallbackHelper, TestHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        lp.mint(cuh, 2 ether);

        vm.prank(cuh);
        lp.approve(address(this), 2 ether);
        lendgine.mintMaker(cuh, 2 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        positionID = Position.getId(cuh);
    }

    function testBurnMakerPartial() public {
        vm.prank(cuh);
        lendgine.burnMaker(cuh, 1 ether);

        assertEq(lp.balanceOf(cuh), 1 ether);
        assertEq(lp.balanceOf(address(lendgine)), 1 ether);
        assertEq(lp.totalSupply(), 2 ether);

        (
            bytes32 next,
            bytes32 previous,
            uint256 liquidity,
            uint256 tokensOwed,
            uint256 rewardPerTokenPaid,
            bool utilized
        ) = lendgine.positions(positionID);

        assertEq(next, bytes32(0));
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 1 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        assertEq(lendgine.lastPosition(), positionID);
        assertEq(lendgine.currentPosition(), positionID);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);
    }

    function testBurnMakerFull() public {
        vm.prank(cuh);
        lendgine.burnMaker(cuh, 2 ether);

        assertEq(lp.balanceOf(cuh), 2 ether);
        assertEq(lp.balanceOf(address(lendgine)), 0 ether);
        assertEq(lp.totalSupply(), 2 ether);

        (
            bytes32 next,
            bytes32 previous,
            uint256 liquidity,
            uint256 tokensOwed,
            uint256 rewardPerTokenPaid,
            bool utilized
        ) = lendgine.positions(positionID);

        assertEq(next, bytes32(0));
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 0 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        assertEq(lendgine.lastPosition(), bytes32(0));
        assertEq(lendgine.currentPosition(), bytes32(0));
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);
    }

    function testZeroBurn() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.burnMaker(cuh, 0 ether);
    }

    function testOverBurn() public {
        vm.prank(cuh);
        lendgine.burnMaker(cuh, 2 ether);
        vm.expectRevert(Lendgine.InsufficientPositionError.selector);
        vm.prank(cuh);
        lendgine.burnMaker(cuh, 1 ether);
    }
}

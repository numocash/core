pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { MintCallbackHelper } from "./utils/MintCallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract BurnTest is TestHelper, MintCallbackHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();
        lp.mint(cuh, 3 ether);

        vm.prank(cuh);
        lp.approve(address(this), 3 ether);
        lendgine.mintMaker(cuh, 3 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        positionID = Position.getId(cuh);

        speculative.mint(cuh, 2 ether);

        vm.prank(cuh);
        speculative.approve(address(this), 2 ether);
        lendgine.mint(cuh, 2 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
    }

    function testBurnPartial() public {
        vm.prank(cuh);
        lp.approve(address(this), 1 ether);
        vm.prank(cuh);
        lendgine.transfer(address(lendgine), 0.1 ether);
        lendgine.burn(cuh, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.1 ether);
        assertEq(lendgine.balanceOf(cuh), 0.1 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // // Test base token
        assertEq(lp.balanceOf(cuh), 0.1 ether);
        assertEq(lp.balanceOf(address(lendgine)), 2.9 ether);

        // Test speculative token
        assertEq(speculative.balanceOf(cuh), 1 ether);
        assertEq(speculative.balanceOf(address(lendgine)), 1 ether);

        // Test position
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
        assertEq(liquidity, 3 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, true);

        // Test global storage values
        assertEq(lendgine.lastPosition(), positionID);
        assertEq(lendgine.currentPosition(), positionID);
        assertEq(lendgine.currentLiquidity(), 0.1 ether);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
    }

    function testBurnFull() public {
        vm.prank(cuh);
        lp.approve(address(this), 2 ether);
        vm.prank(cuh);
        lendgine.transfer(address(lendgine), 0.2 ether);
        lendgine.burn(cuh, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0 ether);
        assertEq(lendgine.balanceOf(cuh), 0 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test lp token
        assertEq(lp.balanceOf(cuh), 0);
        assertEq(lp.balanceOf(address(lendgine)), 3 ether);

        // Test speculative token
        assertEq(speculative.balanceOf(cuh), 2 ether);
        assertEq(speculative.balanceOf(address(lendgine)), 0);

        // Test position
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
        assertEq(liquidity, 3 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        // Test global storage values
        assertEq(lendgine.lastPosition(), positionID);
        assertEq(lendgine.currentPosition(), positionID);
        assertEq(lendgine.currentLiquidity(), 0 ether);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
    }

    function testZeroBurn() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.burn(cuh, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
    }
}

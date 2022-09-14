pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { MintCallbackHelper } from "./utils/MintCallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract CollectTest is TestHelper, MintCallbackHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        lp.mint(cuh, 2 ether);
        vm.prank(cuh);
        lp.approve(address(this), 2 ether);
        lendgine.mintMaker(cuh, 2 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        positionID = Position.getId(cuh);
    }

    function testZeroCollect() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.collectMaker(cuh);
    }

    function testCollect() public {
        speculative.mint(cuh, 1 ether);

        vm.prank(cuh);
        speculative.approve(address(this), 1 ether);
        lendgine.mint(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        vm.warp(1 days + 1);

        lendgine.accrueInterest();
        lendgine.accrueMakerInterest(positionID);

        uint256 dilution = (lendgine.RATE() * 0.1 ether) / 10000;

        vm.prank(cuh);
        lendgine.collectMaker(cuh);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.1 ether);
        assertEq(lendgine.balanceOf(cuh), 0.1 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        assertEq(speculative.totalSupply(), 1 ether);
        assertEq(speculative.balanceOf(cuh), dilution * 10);
        assertEq(speculative.balanceOf(address(lendgine)), 1 ether - dilution * 10);

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
        assertEq(liquidity, 2 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, dilution * 100);
        assertEq(utilized, true);

        // Test global storage values
        assertEq(lendgine.lastPosition(), positionID);
        assertEq(lendgine.currentPosition(), positionID);
        assertEq(lendgine.currentLiquidity(), 0.1 ether - dilution);
        assertEq(lendgine.rewardPerTokenStored(), (dilution * 1 ether * 10) / (0.1 ether));
        assertEq(lendgine.lastUpdate(), 1 days + 1);
    }
}

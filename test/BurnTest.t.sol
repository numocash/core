pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract BurnTest is TestHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        _mintMaker(1 ether, 1 ether, 1, cuh);

        _mint(10 ether, cuh);

        positionID = Position.getId(cuh, 1);
    }

    function testBurnPartial() public {
        _burn(0.5 ether, cuh);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.5 ether);
        assertEq(lendgine.balanceOf(cuh), 0.5 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // // Test base token
        assertEq(pair.balanceOf(cuh), 0.5 ether);
        assertEq(pair.balanceOf(address(lendgine)), 1.5 ether - 1000);

        // Test speculative token
        assertEq(speculative.balanceOf(cuh), 5 ether);
        assertEq(speculative.balanceOf(address(lendgine)), 5 ether);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(positionID);

        assertEq(liquidity, 2 ether - 1000);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 2 ether - 1000);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        // Test global storage values
        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0.5 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.totalLPUtilized(), 0.5 ether);
        assertEq(lendgine.interestNumerator(), 0.5 ether);
    }

    function testBurnFull() public {
        _burn(1 ether, cuh);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0 ether);
        assertEq(lendgine.balanceOf(cuh), 0 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test pair token
        assertEq(pair.balanceOf(cuh), 0);
        assertEq(pair.balanceOf(address(lendgine)), 2 ether - 1000);

        // Test speculative token
        assertEq(speculative.balanceOf(cuh), 10 ether);
        assertEq(speculative.balanceOf(address(lendgine)), 0);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(positionID);

        assertEq(liquidity, 2 ether - 1000);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 2 ether - 1000);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        // Test global storage values
        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.totalLPUtilized(), 0 ether);
        assertEq(lendgine.interestNumerator(), 0);
    }

    function testZeroBurn() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.burn(cuh, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));
    }
}

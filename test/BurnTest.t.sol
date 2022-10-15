pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Position } from "../src/libraries/Position.sol";
import { Tick } from "../src/libraries/Tick.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract BurnTest is TestHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);

        _mint(10 ether, cuh);

        positionID = Position.getID(cuh, 1);
    }

    function testBurnPartial() public {
        _burn(0.5 ether, cuh);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.5 ether);
        assertEq(lendgine.balanceOf(cuh), 0.5 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // // Test base token
        assertEq(pair.buffer(), 0.5 ether);

        // Test speculative token
        assertEq(speculative.balanceOf(cuh), 5 ether);
        assertEq(speculative.balanceOf(address(lendgine)), 5 ether);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), positionID);

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }),
            1
        );

        // Test global storage values
        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0.5 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.interestNumerator(), 0.5 ether);
    }

    function testBurnFull() public {
        _burn(1 ether, cuh);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0 ether);
        assertEq(lendgine.balanceOf(cuh), 0 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test pair token
        assertEq(pair.buffer(), 0 ether);

        // Test speculative token
        assertEq(speculative.balanceOf(cuh), 10 ether);
        assertEq(speculative.balanceOf(address(lendgine)), 0);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), positionID);

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }),
            1
        );

        // Test global storage values
        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.interestNumerator(), 0);
    }

    function testZeroBurn() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.burn(cuh);
    }
}

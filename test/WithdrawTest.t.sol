pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract WithdrawTest is TestHelper {
    function setUp() public {
        _setUp();

        _deposit(1 ether, 8 ether, 1 ether, cuh);
    }

    function testWithdrawPartial() public {
        _withdraw(0.5 ether, cuh);

        assertPosition(Position.Info({ liquidity: 0.5 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuh);

        assertEq(lendgine.totalLiquidity(), 0.5 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0);
        assertEq(lendgine.rewardPerLiquidityStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.buffer(), 0.5 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testWithdrawFull() public {
        _withdraw(1 ether, cuh);

        assertPosition(Position.Info({ liquidity: 0, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuh);

        assertEq(lendgine.totalLiquidity(), 0);
        assertEq(lendgine.totalLiquidityBorrowed(), 0);
        assertEq(lendgine.rewardPerLiquidityStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.buffer(), 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testZeroBurn() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.withdraw(0 ether);
    }

    function testOverBurn() public {
        vm.expectRevert(Lendgine.InsufficientPositionError.selector);
        _withdraw(2 ether, cuh);
    }
}

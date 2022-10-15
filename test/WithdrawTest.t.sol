pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Position } from "../src/libraries/Position.sol";
import { Tick } from "../src/libraries/Tick.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract WithdrawTest is TestHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);

        positionID = Position.getID(cuh, 1);
    }

    function testWithdrawPartial() public {
        _withdraw(0.5 ether, 1, cuh);

        assertEq(pair.buffer(), 0.5 ether);

        assertEq(pair.totalSupply(), 1 ether);

        assertPosition(Position.Info({ liquidity: 0.5 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), positionID);
        assertTick(
            Tick.Info({ liquidity: 0.5 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }),
            1
        );

        assertEq(lendgine.currentTick(), 0);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);
        assertEq(lendgine.interestNumerator(), 0);
    }

    function testWithdrawFull() public {
        _withdraw(1 ether, 1, cuh);

        assertEq(pair.buffer(), 1 ether);
        assertEq(pair.totalSupply(), 1 ether);

        assertPosition(Position.Info({ liquidity: 0, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), positionID);

        assertTick(Tick.Info({ liquidity: 0, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }), 1);

        assertEq(lendgine.currentTick(), 0);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);
        assertEq(lendgine.interestNumerator(), 0);
    }

    function testZeroBurn() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.withdraw(1, 0 ether);
    }

    // function testOverBurn() public {
    //     vm.expectRevert(Lendgine.InsufficientPositionError.selector);
    //     _withdraw(2 ether, 1, cuh);
    // }
}

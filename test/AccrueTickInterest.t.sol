pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Position } from "../src/libraries/Position.sol";
import { Tick } from "../src/libraries/Tick.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract AccrueTickInterestTest is TestHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);

        positionID = Position.getID(cuh, 1);
    }

    function testAccrueInterestBasic() public {
        vm.expectRevert(Lendgine.UnutilizedAccrueError.selector);
        lendgine.accrueTickInterest(1);
    }

    function testAccrueInterstNoTime() public {
        _mint(1 ether, cuh);

        lendgine.accrueTickInterest(1);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.1 ether);
        assertEq(lendgine.balanceOf(cuh), 0.1 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test base token
        assertEq(speculative.balanceOf(cuh), 0);
        assertEq(speculative.balanceOf(address(lendgine)), 1 ether);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), positionID);

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }),
            1
        );

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0.1 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.interestNumerator(), 0.1 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.1 ether);
    }

    function testAccrueInterstTime() public {
        _mint(1 ether, cuh);

        vm.warp(1 days + 1);

        lendgine.accrueTickInterest(1);

        uint256 dilution = 0.1 ether / 10000;

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.1 ether);
        assertEq(lendgine.balanceOf(cuh), 0.1 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test base token
        assertEq(speculative.balanceOf(cuh), 0);
        assertEq(speculative.balanceOf(address(lendgine)), 1 ether);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), positionID);

        assertTick(
            Tick.Info({
                liquidity: 1 ether,
                rewardPerINPaid: dilution * 100,
                tokensOwedPerLiquidity: dilution * 10,
                prev: 0,
                next: 0
            }),
            1
        );

        // Test global storage values
        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0.1 ether - dilution);
        assertEq(lendgine.rewardPerINStored(), (dilution * 10 * 1 ether) / (0.1 ether));
        assertEq(lendgine.lastUpdate(), 1 days + 1);
        assertEq(lendgine.interestNumerator(), 0.1 ether - dilution);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.1 ether - dilution);
    }

    // calling accrue interest twice

    // withdraw and receive correct amount
}

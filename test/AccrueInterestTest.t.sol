pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Position } from "../src/libraries/Position.sol";
import { Tick } from "../src/libraries/Tick.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract AccrueInterestTest is TestHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);

        positionID = Position.getID(cuh, 1);
    }

    function testAccrueInterestBasic() public {
        lendgine.accrueInterest();

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), positionID);

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }),
            1
        );

        assertEq(lendgine.currentTick(), 0);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.interestNumerator(), 0);

        assertEq(pair.buffer(), 0 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testAccrueInterstNoTime() public {
        _mint(1 ether, cuh);

        lendgine.accrueInterest();

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

        lendgine.accrueInterest();

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

    function testMaxAccrue() public {
        _withdraw(1 ether, 1, cuh);
        pair.burn(cuh, 1 ether, 8 ether, 1 ether);
        _deposit(1 ether, 8 ether, 1 ether, 10_000, cuh);
        _mint(1 ether, cuh);

        vm.warp(2 days);

        lendgine.accrueInterest();

        positionID = Position.getID(cuh, 10_000);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.1 ether);
        assertEq(lendgine.balanceOf(cuh), 0.1 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test base token
        assertEq(speculative.balanceOf(cuh), 8 ether);
        assertEq(speculative.balanceOf(address(lendgine)), 1 ether);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), positionID);

        assertTick(
            Tick.Info({
                liquidity: 1 ether,
                rewardPerINPaid: 10**15,
                tokensOwedPerLiquidity: 1 ether,
                prev: 0,
                next: 0
            }),
            10_000
        );

        // Test global storage values
        assertEq(lendgine.currentTick(), 10_000);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 10**15);
        assertEq(lendgine.lastUpdate(), 2 days);
        assertEq(lendgine.interestNumerator(), 0);
        assertEq(lendgine.totalLiquidityBorrowed(), 0);

        vm.prank(cuh);
        lendgine.accruePositionInterest(10_000);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 1 ether, tokensOwed: 1 ether }),
            positionID
        );

        vm.prank(cuh);
        lendgine.collect(cuh, 10_000, 1 ether);

        (, , uint256 tokensOwed) = lendgine.positions(positionID);

        assertEq(tokensOwed, 0);

        assertEq(speculative.balanceOf(cuh), 9 ether);
        assertEq(speculative.balanceOf(address(lendgine)), 0);
    }

    function testMintAfterDilution() public {
        _mint(1 ether, cuh);

        vm.warp(5000 days + 1);

        lendgine.accrueInterest();

        uint256 dilutionLiquidity = 0.05 ether;

        // Test global storage values
        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0.1 ether - dilutionLiquidity);
        assertEq(lendgine.rewardPerINStored(), (dilutionLiquidity * 10 * 1 ether) / (0.1 ether));
        assertEq(lendgine.lastUpdate(), 5000 days + 1);
        assertEq(lendgine.interestNumerator(), 0.1 ether - dilutionLiquidity);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.1 ether - dilutionLiquidity);

        _mint(1 ether, dennis);

        assertEq(lendgine.balanceOf(cuh), 0.1 ether);
        assertEq(lendgine.balanceOf(dennis), 0.2 ether);

        assertEq(lendgine.currentLiquidity(), 0.2 ether - dilutionLiquidity);
        assertEq(lendgine.interestNumerator(), 0.2 ether - dilutionLiquidity);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.2 ether - dilutionLiquidity);
    }

    // calling accrue interest twice

    // withdraw and receive correct amount
}

pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract AccrueInterestTest is TestHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        _mintMaker(1 ether, 1 ether, 1, cuh);

        positionID = Position.getId(cuh, 1);
    }

    function testAccrueInterestBasic() public {
        lendgine.accrueInterest();

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(positionID);

        assertEq(liquidity, 2 ether - 1000);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 2 ether - 1000);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.interestNumerator(), 0);

        assertEq(pair.buffer(), 0 ether);
        assertEq(pair.totalSupply(), 2 ether);
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

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(positionID);

        assertEq(liquidity, 2 ether - 1000);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 2 ether - 1000);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0.1 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.interestNumerator(), 0.1 ether);
    }

    function testAccrueInterstTime() public {
        _mint(1 ether, cuh);

        vm.warp(1 days + 1);

        lendgine.accrueInterest();

        uint256 dilution = (0.1 ether) / 10000;

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.1 ether);
        assertEq(lendgine.balanceOf(cuh), 0.1 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test base token
        assertEq(speculative.balanceOf(cuh), 0);
        assertEq(speculative.balanceOf(address(lendgine)), 1 ether);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(positionID);

        assertEq(liquidity, 2 ether - 1000);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 2 ether - 1000);
        assertEq(rewardPerINPaid, (dilution * 10 * 1 ether) / (0.1 ether));
        // TODO: rounding error here
        assertEq(tokensOwedPerLiquidity, (dilution * 10 * 1 ether) / (2 ether - 1000));

        // Test global storage values
        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0.1 ether - dilution);
        assertEq(lendgine.rewardPerINStored(), (dilution * 10 * 1 ether) / (0.1 ether));
        assertEq(lendgine.lastUpdate(), 1 days + 1);
    }

    // calling accrue interest twice

    // withdraw and receive correct amount
}

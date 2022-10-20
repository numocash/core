pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract AccruePositionInterestTest is TestHelper {
    function setUp() public {
        _setUp();

        _deposit(1 ether, 8 ether, 1 ether, cuh);
    }

    function testAccrueInterestBasic() public {
        lendgine.accruePositionInterest();

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuh);

        assertEq(lendgine.totalLiquidity(), 1 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0 ether);
        assertEq(lendgine.rewardPerLiquidityStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.buffer(), 0 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testAccrueInterstNoTime() public {
        _mint(1 ether, cuh);

        lendgine.accruePositionInterest();

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.1 ether);
        assertEq(lendgine.balanceOf(cuh), 0.1 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test base token
        assertEq(speculative.balanceOf(cuh), 0);
        assertEq(speculative.balanceOf(address(lendgine)), 1 ether);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuh);

        assertEq(lendgine.totalLiquidity(), 1 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.1 ether);
        assertEq(lendgine.rewardPerLiquidityStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.buffer(), 0.1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testAccrueInterstTime() public {
        _mint(5 ether, cuh);

        vm.warp(1 days + 1);

        vm.prank(cuh);
        lendgine.accruePositionInterest();

        uint256 dilutionLP = (0.5 ether * 145) / 1000;

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.5 ether);
        assertEq(lendgine.balanceOf(cuh), 0.5 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test base token
        assertEq(speculative.balanceOf(cuh), 0);
        assertEq(speculative.balanceOf(address(lendgine)), 5 ether);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: dilutionLP * 10, tokensOwed: dilutionLP * 10 }),
            cuh
        );

        // Test global storage values
        assertEq(lendgine.totalLiquidity(), 1 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.5 ether - dilutionLP);
        assertEq(lendgine.rewardPerLiquidityStored(), (dilutionLP * 10));
        assertEq(lendgine.lastUpdate(), 1 days + 1);

        assertEq(pair.buffer(), 0.5 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }
}

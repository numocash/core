pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract CollectTest is TestHelper {
    function setUp() public {
        _setUp();

        _deposit(1 ether, 8 ether, 1 ether, cuh);
    }

    function testCollect() public {
        _mint(5 ether, cuh);

        vm.warp(365 days + 1);

        vm.prank(cuh);
        lendgine.accruePositionInterest();

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        vm.prank(cuh);
        lendgine.collect(cuh, (dilutionLP * 10));

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.5 ether);
        assertEq(lendgine.balanceOf(cuh), 0.5 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        assertEq(speculative.totalSupply(), 13 ether);
        assertEq(speculative.balanceOf(cuh), (dilutionLP * 10));
        assertEq(speculative.balanceOf(address(lendgine)), 5 ether - (dilutionLP * 10));

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: dilutionLP * 10, tokensOwed: 0 }),
            cuh
        );

        // Test global storage values
        assertEq(lendgine.totalLiquidity(), 1 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.5 ether - dilutionLP);
        assertEq(lendgine.rewardPerLiquidityStored(), (dilutionLP * 10));
        assertEq(lendgine.lastUpdate(), 365 days + 1);

        assertEq(pair.buffer(), 0.5 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testPartialCollect() public {
        _mint(5 ether, cuh);

        vm.warp(365 days + 1);

        vm.prank(cuh);
        lendgine.accruePositionInterest();

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        vm.prank(cuh);
        lendgine.collect(cuh, (dilutionLP * 5));

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.5 ether);
        assertEq(lendgine.balanceOf(cuh), 0.5 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        assertEq(speculative.totalSupply(), 13 ether);
        assertEq(speculative.balanceOf(cuh), (dilutionLP * 5));
        assertEq(speculative.balanceOf(address(lendgine)), 5 ether - (dilutionLP * 5));

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: dilutionLP * 10, tokensOwed: dilutionLP * 5 }),
            cuh
        );

        // Test global storage values
        assertEq(lendgine.totalLiquidity(), 1 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.5 ether - dilutionLP);
        assertEq(lendgine.rewardPerLiquidityStored(), (dilutionLP * 10));
        assertEq(lendgine.lastUpdate(), 365 days + 1);

        assertEq(pair.buffer(), 0.5 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testZeroCollect() public {
        _mint(5 ether, cuh);

        vm.warp(365 days + 1);

        vm.prank(cuh);
        lendgine.accruePositionInterest();

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        vm.prank(cuh);
        lendgine.collect(cuh, 0);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.5 ether);
        assertEq(lendgine.balanceOf(cuh), 0.5 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        assertEq(speculative.totalSupply(), 13 ether);
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
        assertEq(lendgine.lastUpdate(), 365 days + 1);

        assertEq(pair.buffer(), 0.5 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testOverCollect() public {
        _mint(5 ether, cuh);

        vm.warp(365 days + 1);

        vm.prank(cuh);
        lendgine.accruePositionInterest();

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        vm.prank(cuh);
        lendgine.collect(cuh, 5 ether);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.5 ether);
        assertEq(lendgine.balanceOf(cuh), 0.5 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        assertEq(speculative.totalSupply(), 13 ether);
        assertEq(speculative.balanceOf(cuh), (dilutionLP * 10));
        assertEq(speculative.balanceOf(address(lendgine)), 5 ether - (dilutionLP * 10));

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: dilutionLP * 10, tokensOwed: 0 }),
            cuh
        );

        // Test global storage values
        assertEq(lendgine.totalLiquidity(), 1 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.5 ether - dilutionLP);
        assertEq(lendgine.rewardPerLiquidityStored(), (dilutionLP * 10));
        assertEq(lendgine.lastUpdate(), 365 days + 1);

        assertEq(pair.buffer(), 0.5 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }
}

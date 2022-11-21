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

    function testUtilizedWithdraw() public {
        _mint(5 ether, cuh);
        _withdraw(0.5 ether, cuh);

        assertPosition(Position.Info({ liquidity: 0.5 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuh);

        assertEq(lendgine.totalLiquidity(), 0.5 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.5 ether);
        assertEq(lendgine.rewardPerLiquidityStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.buffer(), 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testCompleteUtilizationError() public {
        _mint(5 ether, cuh);
        vm.expectRevert(Lendgine.CompleteUtilizationError.selector);
        _withdraw(0.5 ether + 1, cuh);
    }

    function testAccrueOnWithdraw() public {
        _mint(5 ether, cuh);
        pair.burn(cuh, 0.5 ether);
        vm.warp(365 days + 1);

        _withdraw(0.1 ether, cuh);
        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.5 ether);
        assertEq(lendgine.balanceOf(cuh), 0.5 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test base token
        assertEq(speculative.balanceOf(cuh), 4 ether);
        assertEq(speculative.balanceOf(address(lendgine)), 5 ether);

        assertPosition(
            Position.Info({
                liquidity: 0.9 ether,
                rewardPerLiquidityPaid: dilutionLP * 10,
                tokensOwed: dilutionLP * 10
            }),
            cuh
        );

        // Test global storage values
        assertEq(lendgine.totalLiquidity(), 0.9 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.5 ether - dilutionLP);
        assertEq(lendgine.rewardPerLiquidityStored(), (dilutionLP * 10));
        assertEq(lendgine.getSupplyRate(0.5 ether, 1 ether), dilutionLP);
        assertEq(lendgine.lastUpdate(), 365 days + 1);

        // speculative is collateral plus rewards
        uint256 collateral = lendgine.convertLiquidityToAsset(lendgine.convertShareToLiquidity(0.5 ether));
        uint256 rewards = dilutionLP * 10;

        assertEq(speculative.balanceOf(address(lendgine)), collateral + rewards);

        assertEq(pair.buffer(), 0.1 ether);
        assertEq(pair.totalSupply(), 0.5 ether);
    }
}

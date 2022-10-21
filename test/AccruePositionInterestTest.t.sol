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

    function testAccrueEmptyPosition() public {
        vm.prank(dennis);
        vm.expectRevert(Position.NoLiquidityError.selector);
        lendgine.accruePositionInterest();
    }

    function testAccrueInterestBasic() public {
        vm.prank(cuh);
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

        vm.prank(cuh);
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

        vm.warp(365 days + 1);

        vm.prank(cuh);
        lendgine.accruePositionInterest();

        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

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
        assertEq(lendgine.lastUpdate(), 365 days + 1);

        assertEq(pair.buffer(), 0.5 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testAccrueStaggeredDeposits() public {
        _mint(5 ether, cuh);
        pair.burn(cuh, 0.5 ether, 4 ether, 0.5 ether);
        vm.warp(365 days + 1);

        _deposit(1 ether, 8 ether, 1 ether, dennis);
        uint256 dilutionLP = (0.5 ether * 6875) / 10000;

        vm.warp(730 days + 1);

        vm.prank(cuh);
        lendgine.accruePositionInterest();

        vm.prank(dennis);
        lendgine.accruePositionInterest();

        uint256 dilutionLP2 = ((0.5 ether - dilutionLP) * lendgine.getBorrowRate(0.5 ether - dilutionLP, 2 ether)) /
            1 ether;

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.5 ether);
        assertEq(lendgine.balanceOf(cuh), 0.5 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test base token
        assertEq(speculative.balanceOf(cuh), 4 ether);
        assertEq(speculative.balanceOf(address(lendgine)), 5 ether);

        assertPosition(
            Position.Info({
                liquidity: 1 ether,
                rewardPerLiquidityPaid: dilutionLP * 10 + dilutionLP2 * 5,
                tokensOwed: dilutionLP * 10 + dilutionLP2 * 5
            }),
            cuh
        );

        assertPosition(
            Position.Info({
                liquidity: 1 ether,
                rewardPerLiquidityPaid: dilutionLP * 10 + dilutionLP2 * 5,
                tokensOwed: dilutionLP2 * 5
            }),
            dennis
        );

        // Test global storage values
        assertEq(lendgine.totalLiquidity(), 2 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.5 ether - dilutionLP - dilutionLP2);
        assertEq(lendgine.rewardPerLiquidityStored(), dilutionLP * 10 + dilutionLP2 * 5);
        // assertEq(lendgine.getSupplyRate(0.5 ether, 1 ether), dilutionLP);
        assertEq(lendgine.lastUpdate(), 730 days + 1);

        // speculative is collateral plus rewards
        uint256 collateral = lendgine.convertLiquidityToAsset(lendgine.convertShareToLiquidity(0.5 ether));
        uint256 rewards = dilutionLP * 10 + dilutionLP2 * 10;

        assertEq(speculative.balanceOf(address(lendgine)), collateral + rewards);

        assertEq(pair.buffer(), 0 ether);
        assertEq(pair.totalSupply(), 1.5 ether);
    }
}

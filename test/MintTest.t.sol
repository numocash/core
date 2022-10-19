pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";

import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

contract MintTest is TestHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        _deposit(1 ether, 8 ether, 1 ether, cuh);
    }

    function testMint() public {
        _mint(5 ether, cuh);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.5 ether);
        assertEq(lendgine.balanceOf(cuh), 0.5 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuh);

        // Test global storage values
        assertEq(lendgine.totalLiquidity(), 1 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0.5 ether);
        assertEq(lendgine.rewardPerLiquidityStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        // Test pair token
        assertEq(pair.buffer(), 0.5 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testZeroMint() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.mint(
            cuh,
            0 ether,
            abi.encode(CallbackHelper.CallbackData({ speculative: address(speculative), payer: cuh }))
        );
    }

    // TODO: test donations to the pool and extra mints
    // TODO: test insufficient inputs in a different file

    function testExtraMint() public {
        uint256 amountS = 10 ether + 10;

        speculative.mint(cuh, amountS);

        vm.prank(cuh);
        speculative.approve(address(this), amountS);

        vm.expectRevert(Lendgine.CompleteUtilizationError.selector);
        lendgine.mint(
            cuh,
            amountS,
            abi.encode(CallbackHelper.CallbackData({ speculative: address(speculative), payer: cuh }))
        );
    }

    function testEmptyMint() public {
        _withdraw(1 ether, cuh);

        speculative.mint(cuh, 1 ether);

        vm.prank(cuh);
        speculative.approve(address(this), 1 ether);

        vm.expectRevert(Lendgine.CompleteUtilizationError.selector);
        lendgine.mint(
            cuh,
            1 ether,
            abi.encode(CallbackHelper.CallbackData({ speculative: address(speculative), payer: cuh }))
        );
    }

    function testMintFull() public {
        _mint(10 ether, cuh);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 1 ether);
        assertEq(lendgine.balanceOf(cuh), 1 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuh);

        // Test global storage values
        assertEq(lendgine.totalLiquidity(), 1 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 1 ether);
        assertEq(lendgine.rewardPerLiquidityStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        // Test pair token
        assertEq(pair.buffer(), 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }
}

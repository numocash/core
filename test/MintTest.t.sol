pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

contract MintTest is TestHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        _mintMaker(1 ether, 1 ether, 1, cuh);

        positionID = Position.getId(cuh, 1);
    }

    function testMint() public {
        _mint(10 ether, cuh);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 1 ether);
        assertEq(lendgine.balanceOf(cuh), 1 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test pair token
        assertEq(pair.buffer(), 1 ether);
        assertEq(pair.totalSupply(), 2 ether);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(positionID);

        assertEq(liquidity, 2 ether - 1000);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 2 ether - 1000);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        // Test global storage values
        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 1 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.interestNumerator(), 1 ether);
    }

    // function testInsufficientInput() public {
    //     speculative.mint(cuh, 1 ether);

    //     vm.prank(cuh);
    //     speculative.approve(address(this), 1 ether);

    //     vm.expectRevert(Lendgine.InsufficientInputError.selector);

    //     lendgine.mint(
    //         address(this),
    //         2 ether,
    //         abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: address(this) }))
    //     );
    // }

    function testZeroMint() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.mint(cuh, 0 ether, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));
    }

    // function testExtraMint() public {
    //     speculative.mint(cuh, 21 ether);

    //     vm.prank(cuh);
    //     speculative.approve(address(this), 21 ether);

    //     vm.expectRevert(Lendgine.CompleteUtilizationError.selector);
    //     lendgine.mint(cuh, 21 ether, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));
    // }

    // function testEmptyMint() public {
    //     _burnMaker(2 ether - 1000, cuh);

    //     speculative.mint(cuh, 1 ether);

    //     vm.prank(cuh);
    //     speculative.approve(address(this), 1 ether);

    //     vm.expectRevert(Lendgine.CompleteUtilizationError.selector);
    //     lendgine.mint(cuh, 1 ether, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));
    // }

    function testMintFull() public {
        _mint(20 ether - 10_000, cuh);

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 2 ether - 1000);
        assertEq(lendgine.balanceOf(cuh), 2 ether - 1000);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test base token
        assertEq(speculative.balanceOf(cuh), 0);
        assertEq(speculative.balanceOf(address(lendgine)), 20 ether - 10_000);

        assertEq(pair.buffer(), 2 ether - 1000);
        assertEq(pair.totalSupply(), 2 ether);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(positionID);

        assertEq(liquidity, 2 ether - 1000);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 2 ether - 1000);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        // Test global storage values
        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 2 ether - 1000);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.interestNumerator(), 2 ether - 1000);
    }
}

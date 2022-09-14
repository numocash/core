pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { MintCallbackHelper } from "./utils/MintCallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract MintTest is TestHelper, MintCallbackHelper {
    bytes32 public positionID;

    function setUp() public {
        _setUp();

        lp.mint(cuh, 2 ether);

        vm.prank(cuh);
        lp.approve(address(this), 2 ether);

        lendgine.mintMaker(cuh, 2 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        positionID = Position.getId(cuh);
    }

    function testMint() public {
        speculative.mint(cuh, 1 ether);

        vm.prank(cuh);
        speculative.approve(address(this), 1 ether);
        lendgine.mint(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 0.1 ether);
        assertEq(lendgine.balanceOf(cuh), 0.1 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test lp token
        assertEq(lp.balanceOf(cuh), 0.1 ether);

        // Test position
        (
            bytes32 next,
            bytes32 previous,
            uint256 liquidity,
            uint256 tokensOwed,
            uint256 rewardPerTokenPaid,
            bool utilized
        ) = lendgine.positions(positionID);

        assertEq(next, bytes32(0));
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 2 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, true);

        // Test global storage values
        assertEq(lendgine.lastPosition(), positionID);
        assertEq(lendgine.currentPosition(), positionID);
        assertEq(lendgine.currentLiquidity(), 0.1 ether);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);
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

        lendgine.mint(cuh, 0 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
    }

    function testExtraMint() public {
        speculative.mint(cuh, 21 ether);

        vm.prank(cuh);
        speculative.approve(address(this), 21 ether);

        vm.expectRevert(Lendgine.CompleteUtilizationError.selector);
        lendgine.mint(cuh, 21 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
    }

    function testEmptyMint() public {
        vm.prank(cuh);
        lendgine.burnMaker(cuh, 2 ether);

        speculative.mint(cuh, 1 ether);

        vm.prank(cuh);
        speculative.approve(address(this), 1 ether);

        vm.expectRevert(Lendgine.CompleteUtilizationError.selector);
        lendgine.mint(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
    }

    function testMintFull() public {
        speculative.mint(cuh, 20 ether);

        vm.prank(cuh);
        speculative.approve(address(this), 20 ether);
        lendgine.mint(cuh, 20 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        // Test lendgine token
        assertEq(lendgine.totalSupply(), 2 ether);
        assertEq(lendgine.balanceOf(cuh), 2 ether);
        assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

        // Test base token
        assertEq(speculative.balanceOf(cuh), 0);
        assertEq(speculative.balanceOf(address(lendgine)), 20 ether);

        assertEq(lp.balanceOf(address(cuh)), 2 ether);

        // Test position
        (
            bytes32 next,
            bytes32 previous,
            uint256 liquidity,
            uint256 tokensOwed,
            uint256 rewardPerTokenPaid,
            bool utilized
        ) = lendgine.positions(positionID);

        assertEq(next, bytes32(0));
        assertEq(previous, bytes32(0));
        assertEq(liquidity, 2 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, true);

        // Test global storage values
        assertEq(lendgine.lastPosition(), positionID);
        assertEq(lendgine.currentPosition(), positionID);
        assertEq(lendgine.currentLiquidity(), 2 ether);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);
    }
}

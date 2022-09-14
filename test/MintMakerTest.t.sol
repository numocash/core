pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { MintCallbackHelper } from "./utils/MintCallbackHelper.sol";
import { TestHelper } from "./utils/TestHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract MintMakerTest is TestHelper, MintCallbackHelper {
    function setUp() public {
        _setUp();
    }

    function testAddress() public {
        address pairEstimate = LendgineAddress.computeAddress(
            address(factory),
            address(speculative),
            address(lp),
            upperBound
        );

        assertEq(pairEstimate, address(lendgine));
    }

    function testDeployParameters() public {
        assertEq(lendgine.factory(), address(factory));
        assertEq(lendgine.speculativeToken(), address(speculative));
        assertEq(lendgine.lpToken(), address(lp));
        assertEq(lendgine.upperBound(), upperBound);
    }

    function testPositionID() public {
        lp.mint(cuh, 1 ether);

        vm.prank(cuh);
        lp.approve(address(this), 1 ether);

        lendgine.mintMaker(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        bytes32 positionID = Position.getId(cuh);

        bytes32 estimate = keccak256(abi.encodePacked(cuh));

        assertEq(positionID, estimate);
    }

    function testPositionsInit() public {
        lp.mint(cuh, 1 ether);

        vm.prank(cuh);
        lp.approve(address(this), 1 ether);

        lendgine.mintMaker(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

        bytes32 positionID = Position.getId(cuh);

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
        assertEq(liquidity, 1 ether);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        assertEq(lendgine.lastPosition(), positionID);
        assertEq(lendgine.currentPosition(), positionID);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(lp.balanceOf(address(lendgine)), 1 ether);
        assertEq(lp.balanceOf(cuh), 0 ether);
        assertEq(lp.totalSupply(), 1 ether);
    }

    function testZeroMint() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.mintMaker(cuh, 0 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
    }
}

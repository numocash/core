pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

contract MintMakerTest is TestHelper {
    function setUp() public {
        _setUp();
    }

    function testAddress() public {
        address estimate = LendgineAddress.computeAddress(
            address(factory),
            address(speculative),
            address(base),
            upperBound
        );

        assertEq(estimate, address(lendgine));
    }

    function testDeployParameters() public {
        assertEq(lendgine.factory(), address(factory));
        assertEq(lendgine.pair(), address(pair));

        assertEq(pair.token0(), address(speculative));
        assertEq(pair.token1(), address(base));
        assertEq(pair.upperBound(), upperBound);
    }

    function testPositionID() public {
        bytes32 positionID = Position.getId(cuh);

        bytes32 estimate = keccak256(abi.encodePacked(cuh));

        assertEq(positionID, estimate);
    }

    function testPositionsInit() public {
        _mintMaker(1 ether, 1 ether, cuh);

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
        assertEq(liquidity, 2 ether - 1000);
        assertEq(tokensOwed, 0);
        assertEq(rewardPerTokenPaid, 0);
        assertEq(utilized, false);

        assertEq(lendgine.lastPosition(), positionID);
        assertEq(lendgine.currentPosition(), positionID);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerTokenStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.balanceOf(address(lendgine)), 2 ether - 1000);
        assertEq(pair.balanceOf(cuh), 0 ether);
        assertEq(pair.totalSupply(), 2 ether);
    }

    function testZeroMint() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.mintMaker(cuh, 0 ether, abi.encode(CallbackHelper.CallbackData({ key: key, payer: cuh })));
    }
}

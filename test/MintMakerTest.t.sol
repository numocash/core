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
            address(base),
            address(speculative),
            upperBound
        );

        assertEq(factory.getLendgine(address(base), address(speculative), upperBound), estimate);
        assertEq(estimate, address(lendgine));
    }

    function testDeployParameters() public {
        assertEq(lendgine.factory(), address(factory));
        assertEq(lendgine.pair(), address(pair));

        assertEq(pair.speculative(), address(speculative));
        assertEq(pair.base(), address(base));
        assertEq(pair.upperBound(), upperBound);
    }

    function testPositionID() public {
        bytes32 positionID = Position.getId(cuh, 1);

        bytes32 estimate = keccak256(abi.encode(cuh, 1));

        assertEq(positionID, estimate);
    }

    function testPositionsInit() public {
        _mintMaker(1 ether, 8 ether, 1 ether, 1, cuh);

        bytes32 positionID = Position.getId(cuh, 1);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(positionID);

        assertEq(liquidity, 1 ether);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 1 ether);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);
        assertEq(lendgine.interestNumerator(), 0);

        assertEq(pair.buffer(), 0 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testZeroMint() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.deposit(cuh, 1);
    }
}

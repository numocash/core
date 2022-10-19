pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";

import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

contract DepositTest is TestHelper {
    function setUp() public {
        _setUp();
    }

    function testDeployParameters() public {
        assertEq(lendgine.factory(), address(factory));
        assertEq(lendgine.pair(), address(pair));

        assertEq(pair.speculative(), address(speculative));
        assertEq(pair.base(), address(base));
        assertEq(pair.upperBound(), upperBound);
    }

    function testPositionsInit() public {
        _deposit(1 ether, 8 ether, 1 ether, cuh);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuh);

        assertEq(lendgine.totalLiquidity(), 1 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 0);
        assertEq(lendgine.rewardPerLiquidityStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.buffer(), 0 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testZeroMint() public {
        vm.expectRevert(Lendgine.InsufficientOutputError.selector);
        lendgine.deposit(cuh);
    }
}

pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { TickBitMaps } from "../src/libraries/TickBitMaps.sol";

contract MultiUserTest is TestHelper {
    using TickBitMaps for TickBitMaps.TickBitMap;

    TickBitMaps.TickBitMap public tickBitMap;

    function setUp() public {
        _setUp();
    }

    function testEmptyBitMap() public {
        vm.expectRevert();
        tickBitMap.below(1);
    }

    function testFirstTick() public {
        tickBitMap.flipTick(1, true);

        assertEq(tickBitMap.below(2), 1);
    }

    function testSecondTick() public {
        tickBitMap.flipTick(2, true);

        vm.expectRevert();
        assertEq(tickBitMap.below(1), 0);

        tickBitMap.flipTick(1, true);
        assertEq(tickBitMap.below(3), 2);

        tickBitMap.flipTick(2, false);
        assertEq(tickBitMap.below(3), 1);
    }

    function testTwoTicksBelow() public {
        tickBitMap.flipTick(1, true);
        tickBitMap.flipTick(2, true);

        assertEq(tickBitMap.below(3), 2);
    }

    function testBlockBelow() public {
        tickBitMap.flipTick(5, true);

        assertEq(tickBitMap.below(4 << 8), 5);
    }

    function testMaskSameBlock() public {
        tickBitMap.flipTick(4, true);
        tickBitMap.flipTick(7, true);
        assertEq(tickBitMap.blockMap, 1);
        assertEq(tickBitMap.below(5), 4);
        assertEq(tickBitMap.below(10), 7);

        tickBitMap.flipTick(7, false);
        assertEq(tickBitMap.below(10), 4);
    }

    function testMaskBlock() public {
        tickBitMap.flipTick(260, true);
        assertEq(tickBitMap.blockMap, 2);
        tickBitMap.flipTick(1026, true);
        tickBitMap.flipTick(2050, true);

        assertEq(tickBitMap.below(1030), 1026);
        assertEq(tickBitMap.below(1025), 260);
        assertEq(tickBitMap.below(9000), 2050);

        tickBitMap.flipTick(1026, false);

        assertEq(tickBitMap.below(1030), 260);
        assertEq(tickBitMap.below(1025), 260);
        assertEq(tickBitMap.below(9000), 2050);

        tickBitMap.flipTick(2050, false);

        assertEq(tickBitMap.below(1030), 260);
        assertEq(tickBitMap.below(1025), 260);
        assertEq(tickBitMap.below(9000), 260);

        tickBitMap.flipTick(260, false);

        assertEq(tickBitMap.blockMap, 0);
    }
}

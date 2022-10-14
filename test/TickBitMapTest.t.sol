pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
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
        assertEq(tickBitMap.below(1), 0);
        assertEq(tickBitMap.below(2), 0);
    }

    function testFirstTick() public {
        tickBitMap.flipTick(1, true);

        assertEq(tickBitMap.below(2), 1);
    }

    function testSecondTick() public {
        tickBitMap.flipTick(2, true);

        assertEq(tickBitMap.below(1), 0);

        tickBitMap.flipTick(1, true);
        assertEq(tickBitMap.below(3), 2);
    }
}

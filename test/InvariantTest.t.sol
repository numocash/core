pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract InvariantTest is TestHelper {
    function setUp() public {
        _setUp();
    }

    function testLiquidityAmount() public {
        _pairMint(1 ether, 1 ether, cuh);

        assertEq(pair.totalSupply(), k);
        assertEq(pair.buffer(), k - pair.MINIMUM_LIQUIDITY());
    }

    function testBurnAmount() public {
        _pairMint(1 ether, 1 ether, cuh);
        pair.burn(address(cuh));

        assertEq(speculative.balanceOf(cuh), (1 ether * (k - pair.MINIMUM_LIQUIDITY())) / k);
        assertEq(base.balanceOf(cuh), (1 ether * (k - pair.MINIMUM_LIQUIDITY())) / k);

        assertEq(pair.totalSupply(), pair.MINIMUM_LIQUIDITY());
        assertEq(pair.buffer(), 0);
    }
}

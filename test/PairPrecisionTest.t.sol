pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { Pair } from "../src/Pair.sol";

contract InvariantTest is TestHelper {
    function setUp() public {
        _setUp();
    }

    // How much in relative terms does a few lp positions cost
    // How much liquidity can be added until an upper bound is reached
    // concerns are the liquidity is so expensive that 1 wei is too much money for a regular person
    // or that liquidity is so cheap that it starts to reach the max value

    // max asset value: $1,000,000
    // min asset value: $0.000001
    // max bound: 10**9
    // min bound: 10**-9

    // lp value precision: $1
    // max tvl: $100,000,000
    // price precision: $1
    // bound precision: $1

    function testBaseline() public {
        uint256 price = 10**18;
        uint256 r0 = 10**18;
        uint256 r1 = 8 ether;
        _pairMint(1 ether, 8 ether, 1 ether, cuh);

        uint256 value = r0 + (price * r1) / 1 ether;

        uint256 scale = 1 ether; // r0 / $, 1 ether of r0 per dollar

        console2.log("price of 1 ether LP in $:", value / scale);
        console2.log("max TVL of pool in $", (value * 2**128) / (scale * 1 ether));
    }

    function testLPPriceLow() public {
        uint256 price = upperBound / 10**6;
        uint256 r0 = price**2 / 1 ether;
        uint256 r1 = 2 * (upperBound - price);
        _pairMint(r0, r1, 1 ether, cuh);

        uint256 value = r0 + (price * r1) / 1 ether;

        uint256 scale = 1 ether; // r0 / $, 1 ether of r0 per dollar

        console2.log("price of 1 ether LP in $:", value / scale);
        console2.log("max TVL of pool in $", (value * 2**128) / (scale * 1 ether));
    }

    function testLpPriceMax() public {
        uint256 price = upperBound;
        uint256 r0 = price**2 / 1 ether;
        uint256 r1 = 2 * (upperBound - price);
        _pairMint(r0, r1, 1 ether, cuh);

        uint256 value = r0;

        uint256 scale = 1 ether; // r0 / $, 1 ether of r0 per dollar

        console2.log("price of 1 ether LP in $:", value / scale);
        console2.log("max TVL of pool in $", (value * 2**128) / (scale * 1 ether));
    }

    function testPricePrecision() public {
        uint256 price = 10**9 + 1;
        uint256 r0 = (price**2);
        uint256 r1 = 2 * (upperBound - price * 10**9);
        _pairMint(r0, r1, 1 ether, cuh);
    }

    function mintPrecision() public {
        _pairMint(1, 8, 1, cuh);
    }

    // speculative is worth 10**6
    // base is worth 10**-6
    function testHighUpperBoundMax() public {
        uint256 _upperBound = 10**(12 + 18);

        Lendgine _lendgine = Lendgine(factory.createLendgine(address(base), address(speculative), _upperBound));

        Pair _pair = Pair(_lendgine.pair());

        uint256 price = _upperBound;
        uint256 r0 = price**2 / 1 ether;

        base.mint(cuh, r0);

        vm.prank(cuh);
        base.transfer(address(_pair), r0);
        _pair.mint(1 ether);

        uint256 value = r0;

        uint256 scale = 10**24; // r0 / $, 1 ether of r0 per dollar

        console2.log("price of 1 ether LP in $", value / scale);
        console2.log("max TVL of pool in $", (2**128 / scale) * (value / 1 ether));
    }

    function testHighUpperBoundLow() public {
        uint256 _upperBound = 10**(12 + 18);

        Lendgine _lendgine = Lendgine(factory.createLendgine(address(base), address(speculative), _upperBound));

        Pair _pair = Pair(_lendgine.pair());

        uint256 price = 10**24;
        uint256 r0 = price**2 / 1 ether;
        uint256 r1 = 2 * (_upperBound - price);

        base.mint(cuh, r0);
        speculative.mint(cuh, r1);

        vm.prank(cuh);
        base.transfer(address(_pair), r0);
        vm.prank(cuh);
        speculative.transfer(address(_pair), r1);

        _pair.mint(1 ether);

        uint256 value = r0 + (price * r1) / 1 ether;
        uint256 scale = 10**24; // r0 / $, 1 ether of r0 per dollar

        console2.log("price of 1 ether LP in $", value / scale);
        console2.log("max TVL of pool in $", (2**128 / scale) * (value / 1 ether));
    }

    // // price can't be lower than 10**9
    // // upper bound can't be lower than 10**9
    function testLowUpperBoundMax() public {
        uint256 _upperBound = 10**9;

        Lendgine _lendgine = Lendgine(factory.createLendgine(address(base), address(speculative), _upperBound));

        Pair _pair = Pair(_lendgine.pair());

        uint256 price = _upperBound;
        uint256 r0 = price**2 / 1 ether;

        base.mint(cuh, r0);

        vm.prank(cuh);
        base.transfer(address(_pair), r0);

        _pair.mint(1 ether);

        uint256 value = r0;

        uint256 scale = 10**12; // r0 / $, 1 ether of r0 per dollar

        console2.log("price of 1 ether LP in $", value / scale);
        console2.log("max TVL of pool in $", ((2**128 / scale) * value) / 1 ether);
    }

    function testLowUpperBoundLow() public {
        uint256 _upperBound = 10**9;

        Lendgine _lendgine = Lendgine(factory.createLendgine(address(base), address(speculative), _upperBound));

        Pair _pair = Pair(_lendgine.pair());

        uint256 price = 0;
        uint256 r0 = price**2 / 1 ether;
        uint256 r1 = 2 * (_upperBound - price);

        base.mint(cuh, r0);
        speculative.mint(cuh, r1);

        vm.prank(cuh);
        base.transfer(address(_pair), r0);
        vm.prank(cuh);
        speculative.transfer(address(_pair), r1);

        _pair.mint(1 ether);

        uint256 value = r0;

        uint256 scale = 10**12; // r0 / $, 1 ether of r0 per dollar

        console2.log("price of 1 ether LP in $", value / scale);
        console2.log("max TVL of pool in $", ((2**128 / scale) * value) / 1 ether);
    }
}

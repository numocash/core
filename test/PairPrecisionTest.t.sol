pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { Pair } from "../src/Pair.sol";

import { PRBMath } from "prb-math/PRBMath.sol";
import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

contract InvariantTest is TestHelper {
    uint256 public constant maxTokens = type(uint256).max;

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

    /// @dev uses r0 first then r1 if r0 is zero
    function reservesToPrice(
        uint256 r0,
        uint256 r1,
        uint256 liquidity,
        uint256 _upperBound
    ) public returns (uint256 price) {
        if (r0 == 0) {
            uint256 scale0 = PRBMathUD60x18.div(r0, liquidity);
            return PRBMathUD60x18.sqrt(scale0);
        } else {
            uint256 scale1 = PRBMathUD60x18.div(r1, liquidity);
            return _upperBound - scale1 / 2;
        }
    }

    function priceToReserves(
        uint256 price,
        uint256 liquidity,
        uint256 _upperBound
    ) public pure returns (uint256 r0, uint256 r1) {
        uint256 scale0 = PRBMathUD60x18.powu(price, 2);
        uint256 scale1 = 2 * (_upperBound - price);

        return (PRBMathUD60x18.mul(scale0, liquidity), PRBMathUD60x18.mul(scale1, liquidity));
    }

    function priceToLPValue(uint256 price, uint256 _upperBound) public returns (uint256 value) {
        (uint256 r0, uint256 r1) = priceToReserves(price, 1 ether, _upperBound);
        return r0 + PRBMathUD60x18.mul(r1, price);
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

    function testBaseline() public {
        uint256 liquidity = 1 ether;
        uint256 price = 1 ether;
        uint256 conversion = 1 ether; // base to $ scaled

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, upperBound);
        uint256 value = priceToLPValue(price, upperBound);
        _pairMint(r0, r1, liquidity, cuh);

        console2.log("price of 1 ether LP in $:", value / conversion);
        console2.log("max TVL of pool in $", PRBMath.mulDiv(value, maxTokens, conversion * 1 ether));
        // 1 ether is because value is for 1 ether of LP tokens
    }

    function testLPPriceLow() public {
        uint256 liquidity = 1 ether;
        uint256 price = 10**12;
        uint256 conversion = 1 ether; // base to $ scaled

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, upperBound);
        uint256 value = priceToLPValue(price, upperBound);
        _pairMint(r0, r1, liquidity, cuh);

        console2.log("price of 1 ether LP in $:", value / conversion);
        console2.log("max TVL of pool in $", PRBMath.mulDiv(value, maxTokens, conversion * 1 ether));
        // 1 ether is because value is for 1 ether of LP tokens
    }

    function testLPPriceMax() public {
        uint256 liquidity = 1 ether;
        uint256 price = upperBound;
        uint256 conversion = 1 ether; // base to $ scaled

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, upperBound);
        uint256 value = priceToLPValue(price, upperBound);
        _pairMint(r0, r1, liquidity, cuh);

        console2.log("price of 1 ether LP in $:", value / conversion);
        console2.log("max TVL of pool in $", PRBMath.mulDiv(value, maxTokens, conversion * 1 ether));
        // 1 ether is because value is for 1 ether of LP tokens
    }

    function testHighConversionBaseline() public {
        // 10**6 base tokens = $1
        // 10**-3 speculative tokens = $1
        uint256 _upperBound = 10**(9 + 18);
        (, address _pair) = factory.createLendgine(address(base), address(speculative), 18, 18, _upperBound);
        Pair pair = Pair(_pair);

        uint256 liquidity = 1 ether;
        uint256 price = _upperBound / 10;
        uint256 conversion = 10**(6 + 18);

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, _upperBound);

        uint256 value = priceToLPValue(price, _upperBound);
        _pairMint(r0, r1, liquidity, cuh, pair);

        console2.log("price of 1 ether LP in $:", value / conversion);
        console2.log("max TVL of pool in $", PRBMath.mulDiv(value, maxTokens, conversion * 1 ether));
    }

    function testHighConversionPriceMax() public {
        // 10**6 base tokens = $1
        // 10**-3 speculative tokens = $1
        uint256 _upperBound = 10**(9 + 18);
        (, address _pair) = factory.createLendgine(address(base), address(speculative), 18, 18, _upperBound);
        Pair pair = Pair(_pair);

        uint256 liquidity = 1 ether;
        uint256 price = _upperBound;
        uint256 conversion = 10**(6 + 18);

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, _upperBound);

        uint256 value = priceToLPValue(price, _upperBound);
        _pairMint(r0, r1, liquidity, cuh, pair);

        console2.log("price of 1 ether LP in $:", value / conversion);
        console2.log("max TVL of pool in $", PRBMath.mulDiv(value, maxTokens, conversion * 1 ether));
    }

    function testHighConversionPriceLow() public {
        // 10**6 base tokens = $1
        // 10**-3 speculative tokens = $1
        uint256 _upperBound = 10**(9 + 18);
        (, address _pair) = factory.createLendgine(address(base), address(speculative), 18, 18, _upperBound);
        Pair pair = Pair(_pair);

        uint256 liquidity = 1 ether;
        uint256 price = _upperBound / 10**6;
        uint256 conversion = 10**(6 + 18);

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, _upperBound);

        uint256 value = priceToLPValue(price, _upperBound);
        _pairMint(r0, r1, liquidity, cuh, pair);

        console2.log("price of 1 ether LP in $:", value / conversion);
        console2.log("max TVL of pool in $", PRBMath.mulDiv(value, maxTokens, conversion * 1 ether));
    }

    function testLowConversionBaseline() public {
        // 10**-6 base tokens = $1
        // 10**3 speculative tokens = $1
        uint256 _upperBound = 10**(18 - 9);
        (, address _pair) = factory.createLendgine(address(base), address(speculative), 18, 18, _upperBound);
        Pair pair = Pair(_pair);

        uint256 liquidity = 1 ether;
        uint256 price = _upperBound / 10;
        uint256 conversion = 10**(18 - 6);

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, _upperBound);

        uint256 value = priceToLPValue(price, _upperBound);
        _pairMint(r0, r1, liquidity, cuh, pair);

        console2.log("price of 1 ether LP in $:", value / conversion);
        console2.log("max TVL of pool in $", PRBMath.mulDiv(value, maxTokens, conversion * 1 ether));
    }

    function testLowConversionPriceMax() public {
        // 10**-6 base tokens = $1
        // 10**3 speculative tokens = $1
        uint256 _upperBound = 10**(18 - 9);
        (, address _pair) = factory.createLendgine(address(base), address(speculative), 18, 18, _upperBound);
        Pair pair = Pair(_pair);

        uint256 liquidity = 1 ether;
        uint256 price = _upperBound;
        uint256 conversion = 10**(18 - 6);

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, _upperBound);

        uint256 value = priceToLPValue(price, _upperBound);
        _pairMint(r0, r1, liquidity, cuh, pair);

        console2.log("price of 1 ether LP in $:", value / conversion);
        console2.log("max TVL of pool in $", PRBMath.mulDiv(value, maxTokens, conversion * 1 ether));
    }

    function testLowConversionPriceLow() public {
        // 10**-6 base tokens = $1
        // 10**3 speculative tokens = $1
        uint256 _upperBound = 10**(18 - 9);
        (, address _pair) = factory.createLendgine(address(base), address(speculative), 18, 18, _upperBound);
        Pair pair = Pair(_pair);

        uint256 liquidity = 1 ether;
        uint256 price = _upperBound / 10**6;
        uint256 conversion = 10**(18 - 6);

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, _upperBound);

        uint256 value = priceToLPValue(price, _upperBound);
        _pairMint(r0, r1, liquidity, cuh, pair);

        console2.log("price of 1 ether LP in $:", value / conversion);
        console2.log("max TVL of pool in $", PRBMath.mulDiv(value, maxTokens, conversion * 1 ether));
    }

    function testLowDecimalsBase() public {
        uint256 _upperBound = 5 ether;
        (, address _pair) = factory.createLendgine(address(base), address(speculative), 9, 18, _upperBound);
        Pair pair = Pair(_pair);

        uint256 liquidity = 1 ether;
        uint256 price = 1 ether;

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, _upperBound);

        _pairMint(r0 / 10**9, r1, liquidity, cuh, pair);
    }

    function testLowDecimalsSpeculative() public {
        uint256 _upperBound = 5 ether;
        (, address _pair) = factory.createLendgine(address(base), address(speculative), 18, 9, _upperBound);
        Pair pair = Pair(_pair);

        uint256 liquidity = 1 ether;
        uint256 price = 1 ether;

        (uint256 r0, uint256 r1) = priceToReserves(price, liquidity, _upperBound);

        _pairMint(r0, r1 / 10**9, liquidity, cuh, pair);
    }
}

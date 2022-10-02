pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { Math } from "../src/libraries/Math.sol";

contract InvariantTest is TestHelper {
    function setUp() public {
        _setUp();
    }

    function testLiquidityAmount() public {
        _pairMint(1 ether, 1 ether, cuh);

        assertEq(pair.totalSupply(), k);
        assertEq(pair.buffer(), k);
    }

    function testBurnAmount() public {
        _pairMint(1 ether, 1 ether, cuh);
        uint256 amount0 = 1 ether;
        uint256 amount1 = 1 ether;
        pair.burn(cuh, amount0, amount1);

        assertEq(speculative.balanceOf(cuh), 1 ether);
        assertEq(base.balanceOf(cuh), 1 ether);

        assertEq(pair.totalSupply(), 0);
        assertEq(pair.buffer(), 0);
    }

    function testDouble() public {
        _mintMaker(1 ether, 1 ether, 1, cuh);
        _pairMint(1_000_000, 1_000_000, dennis);

        uint256 k2 = 10**24 + 5 * 10**24 - 10**12 / 4;

        assertEq(pair.totalSupply(), k + k2);
        assertEq(pair.buffer(), k2);

        pair.burn(dennis, 1_000_000, 1_000_000);

        assertEq(speculative.balanceOf(dennis), 1_000_000);
        assertEq(base.balanceOf(dennis), 1_000_000);

        assertEq(pair.buffer(), 0);
        assertEq(pair.totalSupply(), k);

        _burnMaker(k, 1, cuh);

        assertEq(pair.buffer(), k);
        assertEq(pair.totalSupply(), k);

        pair.burn(cuh, 1 ether, 1 ether);

        assertEq(pair.totalSupply(), 0);
        assertEq(pair.buffer(), 0);
    }

    struct SwapCallbackData {
        LendgineAddress.LendgineKey key;
        address payer;
        uint256 amount0In;
        uint256 amount1In;
    }

    function SwapCallback(
        uint256,
        uint256,
        bytes calldata data
    ) external {
        SwapCallbackData memory decoded = abi.decode(data, (SwapCallbackData));
        // CallbackValidation.verifyCallback(factory, decoded.poolKey);

        if (decoded.amount0In > 0) pay(ERC20(decoded.key.base), decoded.payer, msg.sender, decoded.amount0In);
        if (decoded.amount1In > 0) pay(ERC20(decoded.key.speculative), decoded.payer, msg.sender, decoded.amount1In);
    }

    function testSwap() public {
        uint256 rB = 0 ether;
        uint256 rS = 2 ether;
        _pairMint(rB, rS, cuh);

        uint256 amountSOut = 0.00001 ether;

        uint256 a = (amountSOut * upperBound) / 1 ether;

        uint256 b = (amountSOut**2) / 4 ether;

        uint256 c = (amountSOut * rS) / 2 ether;

        uint256 amountBIn = a + b - c;

        base.mint(cuh, amountBIn);

        vm.prank(cuh);
        base.approve(address(this), amountBIn);

        pair.swap(
            cuh,
            0,
            amountSOut,
            abi.encode(SwapCallbackData({ key: key, payer: cuh, amount0In: amountBIn, amount1In: 0 }))
        );
    }

    function testPrice() public {
        uint256 rB = 0 ether;
        uint256 rS = 2 ether;
        _pairMint(rB, rS, cuh);

        uint256 amountSOut = .00000001 ether;

        uint256 a = (amountSOut * upperBound) / 1 ether;
        uint256 b = (amountSOut**2) / 4 ether;
        uint256 c = (amountSOut * rS) / 2 ether;

        uint256 amountBIn = a + b - c;

        uint256 priceS = (amountBIn * 1 ether) / amountSOut;
        console2.log(priceS, "usd per eth");

        uint256 p = upperBound - rS / 2;

        console2.log(p);
    }

    function testPrice2() public {
        uint256 rB = 8 ether;
        uint256 rS = 0.1 ether;
        _pairMint(rB, rS, cuh);

        uint256 amountSOut = .00000001 ether;

        uint256 a = (amountSOut * upperBound) / 1 ether;
        uint256 b = (amountSOut**2) / 4 ether;
        uint256 c = (amountSOut * rS) / 2 ether;

        uint256 amountBIn = a + b - c;

        uint256 priceS = (amountBIn * 1 ether) / amountSOut;
        console2.log(priceS, "usd per eth");

        uint256 p = upperBound - rS / 2;

        console2.log(p);
    }

    // test swap to the upper bound

    function testSwapUpperBound() public {
        uint256 rB = 0 ether;
        uint256 rS = 2 ether;
        _pairMint(rB, rS, cuh);

        uint256 amountSOut = 2 ether;

        uint256 a = (amountSOut * upperBound) / 1 ether;
        uint256 b = (amountSOut**2) / 4 ether;
        uint256 c = (amountSOut * rS) / 2 ether;

        uint256 amountBIn = a + b - c;

        base.mint(cuh, amountBIn);

        vm.prank(cuh);
        base.approve(address(this), amountBIn);

        pair.swap(
            cuh,
            0,
            amountSOut,
            abi.encode(SwapCallbackData({ key: key, payer: cuh, amount0In: amountBIn, amount1In: 0 }))
        );

        (uint256 balanceBase, uint256 balanceSpec) = pair.balances();

        assertEq(balanceBase, amountBIn);
        assertEq(balanceSpec, 0);
    }
}

pragma solidity ^0.8.0;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { Pair } from "../src/Pair.sol";

import { PRBMath } from "prb-math/PRBMath.sol";
import { PRBMathUD60x18 } from "prb-math/PRBMathUD60x18.sol";

contract InvariantTest is TestHelper {
    function setUp() public {
        _setUp();
    }

    function testLiquidityAmount() public {
        _pairMint(9 ether, 4 ether, 1 ether, cuh);

        assertEq(pair.totalSupply(), 1 ether);
        assertEq(pair.buffer(), 1 ether);
    }

    function testBaseUpperBound() public {
        _pairMint(25 ether, 0, 1 ether, cuh);
    }

    function testSpeculativeUpperBound() public {
        _pairMint(0 ether, 2 * upperBound, 1 ether, cuh);
    }

    function testTooLargeScale() public {
        base.mint(cuh, 9 ether);
        speculative.mint(cuh, 4 ether);

        vm.prank(cuh);
        base.transfer(address(pair), 9 ether);

        vm.prank(cuh);
        speculative.transfer(address(this), 4 ether);

        vm.expectRevert(Pair.InvariantError.selector);
        pair.mint(1 ether);
    }

    function testTooSmallScale() public {
        base.mint(cuh, 9 ether);
        speculative.mint(cuh, 4 ether);

        vm.prank(cuh);
        base.transfer(address(pair), 9 ether);

        vm.prank(cuh);
        speculative.transfer(address(this), 4 ether);

        vm.expectRevert(Pair.InvariantError.selector);
        pair.mint(1 ether);
    }

    function testSpeculativeUpperBound2() public {
        _pairMint(0 ether, 10 ether, 1 ether, cuh);
    }

    function testLargeScale() public {
        _pairMint(10**27, 8 * 10**27, 10**27, cuh);
    }

    function testSmallScale() public {
        _pairMint(1_000_000, 8_000_000, 1_000_000, cuh);
    }

    function testDivideToZero() public {
        base.mint(cuh, 9 ether);
        speculative.mint(cuh, 4 ether);

        vm.prank(cuh);
        base.transfer(address(pair), 9 ether);

        vm.prank(cuh);
        speculative.transfer(address(this), 4 ether);

        vm.expectRevert(Pair.InvariantError.selector);
        pair.mint(1 ether);
    }

    function testDivideByZero() public {
        base.mint(cuh, 9 ether);
        speculative.mint(cuh, 4 ether);

        vm.prank(cuh);
        base.transfer(address(pair), 9 ether);

        vm.prank(cuh);
        speculative.transfer(address(this), 4 ether);

        vm.expectRevert(Pair.InsufficientOutputError.selector);
        pair.mint(0 ether);
    }

    function testSpeculativeInvariantError() public {
        speculative.mint(cuh, 2 * upperBound + 1);

        vm.prank(cuh);
        speculative.transfer(address(pair), 2 * upperBound + 1);

        vm.expectRevert(Pair.SpeculativeInvariantError.selector);
        pair.mint(1 ether);
    }

    function testBaseInvariantError() public {
        base.mint(cuh, 25 ether + 1);

        vm.prank(cuh);
        base.transfer(address(pair), 25 ether + 1);

        vm.expectRevert(Pair.InvariantError.selector);
        pair.mint(1 ether);
    }

    function testBurnAmount() public {
        _pairMint(9 ether, 4 ether, 1 ether, cuh);

        pair.burn(cuh, 1 ether);
        assertEq(base.balanceOf(cuh), 9 ether);
        assertEq(speculative.balanceOf(cuh), 4 ether);

        assertEq(pair.totalSupply(), 0);
        assertEq(pair.buffer(), 0);
    }

    function testDouble() public {
        _deposit(1 ether, 8 ether, 1 ether, cuh);
        _pairMint(1_000_000, 8_000_000, 1_000_000, dennis);

        assertEq(pair.totalSupply(), 1 ether + 1_000_000);
        assertEq(pair.buffer(), 1_000_000);

        pair.burn(dennis, 1_000_000);

        assertEq(base.balanceOf(dennis), 1_000_000);
        assertEq(speculative.balanceOf(dennis), 8_000_000);

        assertEq(pair.buffer(), 0);
        assertEq(pair.totalSupply(), 1 ether);

        _withdraw(1 ether, cuh);

        assertEq(pair.buffer(), 1 ether);
        assertEq(pair.totalSupply(), 1 ether);

        pair.burn(cuh, 1 ether);

        assertEq(pair.totalSupply(), 0);
        assertEq(pair.buffer(), 0);

        assertEq(base.balanceOf(cuh), 1 ether);
        assertEq(speculative.balanceOf(cuh), 8 ether);
    }

    function testSwapBForS1() public {
        uint256 rB = 1 ether;
        uint256 rS = 8 ether;
        _pairMint(rB, rS, 1 ether, cuh);

        uint256 amountSOut = 0.00001 ether;

        uint256 a = PRBMathUD60x18.mul(amountSOut, upperBound);

        uint256 b = PRBMathUD60x18.powu(amountSOut, 2) / 4;

        uint256 c = PRBMathUD60x18.mul(amountSOut, rS) / 2;

        uint256 amountBIn = a + b - c;

        base.mint(cuh, amountBIn);
        console2.log(amountBIn);

        vm.prank(cuh);
        base.transfer(address(pair), amountBIn);

        console2.log("quote price", 1 ether);
        console2.log("trade price", (amountBIn * 1 ether) / amountSOut);

        pair.swap(cuh, 0, amountSOut);
    }

    function testSwapBForS2() public {
        uint256 rB = 1 ether;
        uint256 rS = 8 ether;
        _pairMint(rB, rS, 1 ether, cuh);

        uint256 amountBOut = 10000025000000 - 50000000;

        uint256 a = 2 * upperBound - rS;

        uint256 b = 4 * amountBOut;

        uint256 c = PRBMathUD60x18.sqrt(PRBMathUD60x18.powu(a, 2) - b);

        uint256 amountSIn = a - c;

        console2.log("base out", amountBOut);
        console2.log("spec in", amountSIn);

        console2.log("quote price", 1 ether);
        console2.log("trade price", (amountBOut * 1 ether) / amountSIn);

        speculative.mint(cuh, amountSIn);

        vm.prank(cuh);
        speculative.transfer(address(pair), amountSIn);

        pair.swap(cuh, amountBOut, 0);
    }

    function testSwapUpperBound() public {
        uint256 rB = 0 ether;
        uint256 rS = 2 ether;
        _pairMint(rB, rS, 1 ether / 5, cuh);

        uint256 amountSOut = 2 ether;

        uint256 amountBIn = 5 ether;

        base.mint(cuh, amountBIn);

        vm.prank(cuh);
        base.transfer(address(pair), amountBIn);

        pair.swap(cuh, 0, amountSOut);

        uint256 balanceBase = pair.reserve0();
        uint256 balanceSpec = pair.reserve1();

        assertEq(balanceBase, amountBIn);
        assertEq(balanceSpec, 0);
    }

    // pair value must never exceed the portfolio value
    function testBurnWithDonation() public {
        _pairMint(9 ether, 4 ether, 1 ether, cuh);

        base.mint(dennis, 9 ether);
        speculative.mint(dennis, 4 ether);

        vm.startPrank(dennis);
        base.transfer(address(pair), 9 ether);
        speculative.transfer(address(pair), 4 ether);
        vm.stopPrank();

        pair.burn(cuh, 1 ether);

        assertEq(base.balanceOf(cuh), 9 ether);
        assertEq(speculative.balanceOf(cuh), 4 ether);

        assertEq(pair.totalSupply(), 0 ether);
        assertEq(pair.buffer(), 0 ether);

        assertEq(base.balanceOf(address(pair)), 9 ether);
        assertEq(speculative.balanceOf(address(pair)), 4 ether);

        pair.skim(dennis);
        assertEq(base.balanceOf(dennis), 9 ether);
        assertEq(speculative.balanceOf(dennis), 4 ether);
    }

    function testMintWithDonation() public {
        _deposit(9 ether, 4 ether, 1 ether, cuh);

        base.mint(address(pair), 9 ether);
        speculative.mint(address(pair), 4 ether);

        pair.mint(1 ether);

        pair.burn(dennis, 1 ether);

        assertEq(base.balanceOf(dennis), 9 ether);
        assertEq(speculative.balanceOf(dennis), 4 ether);

        assertEq(pair.totalSupply(), 1 ether);
        assertEq(pair.buffer(), 0);

        _withdraw(1 ether, cuh);

        assertEq(pair.buffer(), 1 ether);
        assertEq(pair.totalSupply(), 1 ether);

        pair.burn(cuh, 1 ether);

        assertEq(pair.totalSupply(), 0);
        assertEq(pair.buffer(), 0);

        assertEq(base.balanceOf(cuh), 9 ether);
        assertEq(speculative.balanceOf(cuh), 4 ether);
    }

    function testSwapWithDonations() public {
        _pairMint(1 ether, 8 ether, 1 ether, cuh);

        base.mint(address(pair), 1_000_000);
        speculative.mint(address(pair), 8_000_000);

        uint256 amountSOut = 0.00001 ether;

        uint256 a = (amountSOut * upperBound) / 10**18;

        uint256 b = (amountSOut**2) / 4 ether;

        uint256 c = (amountSOut * 8 ether) / 2 ether;

        uint256 amountBIn = a + b - c;

        base.mint(cuh, amountBIn - 1_000_000);

        vm.prank(cuh);
        base.transfer(address(pair), amountBIn - 1_000_000);

        pair.swap(cuh, 0, amountSOut + 8_000_000);
    }
}

pragma solidity ^0.8.4;

import { Factory } from "../../src/Factory.sol";
import { Pair } from "../../src/Pair.sol";
import { Lendgine } from "../../src/Lendgine.sol";

import { Position } from "../../src/libraries/Position.sol";

import { MockERC20 } from "./mocks/MockERC20.sol";
import { CallbackHelper } from "./CallbackHelper.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

abstract contract TestHelper is Test, CallbackHelper {
    MockERC20 public immutable base;
    MockERC20 public immutable speculative;

    uint256 public immutable upperBound = 5 * 10**18;

    address public immutable cuh;
    address public immutable dennis;

    Factory public factory;

    Lendgine public lendgine;

    Pair public pair;

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }

    constructor() {
        speculative = new MockERC20();
        base = new MockERC20();

        cuh = mkaddr("cuh");
        dennis = mkaddr("dennis");
    }

    function _setUp() internal {
        factory = new Factory();

        address _lendgine = factory.createLendgine(address(base), address(speculative), 18, 18, upperBound);

        lendgine = Lendgine(_lendgine);

        address _pair = lendgine.pair();

        pair = Pair(_pair);
    }

    function _deposit(
        uint256 amountBase,
        uint256 amountSpeculative,
        uint256 liquidity,
        address spender
    ) internal {
        _pairMint(amountBase, amountSpeculative, liquidity, spender);

        lendgine.deposit(spender);
    }

    function _pairMint(
        uint256 amountBase,
        uint256 amountSpeculative,
        uint256 liquidity,
        address spender
    ) internal {
        base.mint(spender, amountBase);
        speculative.mint(spender, amountSpeculative);

        if (spender != address(this)) {
            vm.prank(spender);
            speculative.transfer(address(pair), amountSpeculative);

            vm.prank(spender);
            base.transfer(address(pair), amountBase);
        }

        pair.mint(liquidity);
    }

    function _pairMint(
        uint256 amountBase,
        uint256 amountSpeculative,
        uint256 liquidity,
        address spender,
        Pair _pair
    ) internal {
        base.mint(spender, amountBase);
        speculative.mint(spender, amountSpeculative);

        if (spender != address(this)) {
            vm.prank(spender);
            speculative.transfer(address(_pair), amountSpeculative);

            vm.prank(spender);
            base.transfer(address(_pair), amountBase);
        }

        _pair.mint(liquidity);
    }

    function _withdraw(uint256 amountLP, address spender) internal {
        vm.prank(spender);
        lendgine.withdraw(amountLP);
    }

    function _mint(uint256 amount, address spender) internal {
        speculative.mint(spender, amount);

        if (spender != address(this)) {
            vm.prank(spender);
            speculative.approve(address(this), amount);
        }
        lendgine.mint(
            spender,
            amount,
            abi.encode(CallbackHelper.CallbackData({ speculative: address(speculative), payer: spender }))
        );
    }

    function _burn(uint256 amount, address spender) internal {
        vm.prank(spender);
        lendgine.approve(address(this), amount);

        lendgine.transferFrom(spender, address(lendgine), amount);
        lendgine.burn(spender);
    }

    function assertPosition(Position.Info memory positionInfo, address owner) internal {
        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(owner);

        assertEq(positionInfo.liquidity, liquidity);
        assertEq(positionInfo.rewardPerLiquidityPaid, rewardPerLiquidityPaid);
        assertEq(positionInfo.tokensOwed, tokensOwed);
    }
}

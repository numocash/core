pragma solidity ^0.8.4;

import { LendgineAddress } from "../../src/libraries/LendgineAddress.sol";

import { Factory } from "../../src/Factory.sol";
import { Pair } from "../../src/Pair.sol";
import { Lendgine } from "../../src/Lendgine.sol";

import { MockERC20 } from "./mocks/MockERC20.sol";
import { CallbackHelper } from "./CallbackHelper.sol";

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

abstract contract TestHelper is Test, CallbackHelper {
    MockERC20 public immutable speculative;
    MockERC20 public immutable base;

    uint256 public immutable upperBound = 5 ether;

    uint256 public immutable k = 5 ether**2 + 1 ether - (5 ether - 1 ether / 2)**2;

    address public immutable cuh;
    address public immutable dennis;

    LendgineAddress.LendgineKey public key;

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

        key = LendgineAddress.getLendgineKey(address(speculative), address(base), upperBound);
    }

    function _setUp() internal {
        factory = new Factory();

        address _lendgine = factory.createLendgine(address(speculative), address(base), upperBound);

        lendgine = Lendgine(_lendgine);

        address _pair = lendgine.pair();

        pair = Pair(_pair);
    }

    function _mintMaker(
        uint256 amountSpeculative,
        uint256 amountBase,
        uint24 tick,
        address spender
    ) internal {
        speculative.mint(spender, amountSpeculative);
        base.mint(spender, amountBase);

        if (spender != address(this)) {
            vm.prank(spender);
            speculative.approve(address(this), amountSpeculative);

            vm.prank(spender);
            base.approve(address(this), amountBase);
        }

        pair.mint(amountSpeculative, amountBase, abi.encode(CallbackHelper.CallbackData({ key: key, payer: spender })));

        lendgine.mintMaker(spender, tick);
    }

    function _pairMint(
        uint256 amountSpeculative,
        uint256 amountBase,
        address spender
    ) internal {
        speculative.mint(spender, amountSpeculative);
        base.mint(spender, amountBase);

        if (spender != address(this)) {
            vm.prank(spender);
            speculative.approve(address(this), amountSpeculative);

            vm.prank(spender);
            base.approve(address(this), amountBase);
        }

        pair.mint(amountSpeculative, amountBase, abi.encode(CallbackHelper.CallbackData({ key: key, payer: spender })));
    }

    function _burnMaker(
        uint256 amountLP,
        uint24 tick,
        address spender
    ) internal {
        vm.prank(spender);
        lendgine.burnMaker(tick, amountLP);
    }

    function _mint(uint256 amount, address spender) internal {
        speculative.mint(spender, amount);

        if (spender != address(this)) {
            vm.prank(spender);
            speculative.approve(address(this), amount);
        }

        lendgine.mint(spender, amount, abi.encode(CallbackHelper.CallbackData({ key: key, payer: spender })));
    }

    function _burn(uint256 amount, address spender) internal {
        vm.prank(spender);
        lendgine.transfer(address(lendgine), amount);

        lendgine.burn(spender);
    }
}

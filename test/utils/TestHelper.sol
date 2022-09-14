pragma solidity ^0.8.4;

import { LendgineAddress } from "../../src/libraries/LendgineAddress.sol";

import { Factory } from "../../src/Factory.sol";
import { Lendgine } from "../../src/Lendgine.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

import { Test } from "forge-std/Test.sol";

abstract contract TestHelper is Test {
    MockERC20 public immutable speculative;
    MockERC20 public immutable lp;

    uint256 public immutable upperBound = 5 ether;

    address public immutable cuh;
    address public immutable dennis;

    LendgineAddress.LendgineKey public key;

    Factory public factory;

    Lendgine public lendgine;

    function mkaddr(string memory name) public returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))));
        vm.label(addr, name);
        return addr;
    }

    constructor() {
        speculative = new MockERC20();
        lp = new MockERC20();

        cuh = mkaddr("cuh");
        dennis = mkaddr("dennis");

        key = LendgineAddress.getLendgineKey(address(speculative), address(lp), upperBound);
    }

    function _setUp() internal {
        factory = new Factory();

        address _lendgine = factory.createLendgine(address(speculative), address(lp), upperBound);
        lendgine = Lendgine(_lendgine);
    }
}

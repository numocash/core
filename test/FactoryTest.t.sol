pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

contract DepositTest is TestHelper {
    function setUp() public {
        _setUp();
    }

    function testDeployAddress() public {
        address estimate = LendgineAddress.computeAddress(
            address(factory),
            address(base),
            address(speculative),
            18,
            18,
            upperBound
        );

        address factoryAddress = factory.getLendgine(address(base), address(speculative), 18, 18, upperBound);

        assertEq(address(lendgine), estimate);
        assertEq(address(lendgine), factoryAddress);
    }

    function testDeployAddress2() public {
        address _lendgine = factory.createLendgine(address(speculative), address(base), 18, 18, upperBound);

        address estimate = LendgineAddress.computeAddress(
            address(factory),
            address(speculative),
            address(base),
            18,
            18,
            upperBound
        );

        address factoryAddress = factory.getLendgine(address(speculative), address(base), 18, 18, upperBound);

        assertEq(_lendgine, estimate);
        assertEq(_lendgine, factoryAddress);
        assertTrue(_lendgine != address(lendgine));
    }
}

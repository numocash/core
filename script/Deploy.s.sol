// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Factory } from "../src/Factory.sol";

contract DeployScript is Script {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        new Factory();
    }
}

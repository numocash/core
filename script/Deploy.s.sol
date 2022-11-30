// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { Factory } from "../src/Factory.sol";
import { CREATE3Factory } from "create3-factory/CREATE3Factory.sol";
import { Pair } from "../src/Pair.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract DeployScript is Script {
    function run() public returns (Factory deployed) {
        CREATE3Factory create3 = CREATE3Factory(vm.envAddress("CREATE3"));

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);

        deployed = Factory(create3.deploy(keccak256("NumoenFactory01"), type(Factory).creationCode));

        console2.log("Lendgine initcode hash:", uint256(keccak256(type(Lendgine).creationCode)));
        console2.log("Pair initcode hash:", uint256(keccak256(type(Pair).creationCode)));
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

contract DeployScript is Script {
    function run() public {
        address factory = 0xa284973f0EB3542Af62dB35E65766D0ef9a4c71b;
        address base = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
        address speculative = 0x471EcE3750Da237f93B8E339c536989b8978a438;
        uint256 upperBound = 5 ether;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        address lendgine = Factory(factory).createLendgine(base, speculative, 18, 18, upperBound);

        address pair = Lendgine(lendgine).pair();

        console2.log("lendgine", lendgine);
        console2.log("pair", pair);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract DeployScript is Script {
    function run() public {
        address factory = 0x519C8f2D26a656d12582f418d6B460e57867ee5e;
        address base = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
        address speculative = 0x471EcE3750Da237f93B8E339c536989b8978a438;
        uint256 upperBound = 5 ether;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        address lendgine = Factory(factory).createLendgine(base, speculative, upperBound);

        address pair = Lendgine(lendgine).pair();

        console2.log("lendgine", lendgine);
        console2.log("pair", pair);
    }
}

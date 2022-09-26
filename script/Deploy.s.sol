// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        Factory factory = new Factory();
        vm.broadcast(pk);
        // factory.createLendgine(0x471EcE3750Da237f93B8E339c536989b8978a438, 0x765DE816845861e75A25fCA122bb6898B8B1282a, 2.5 ether);

        // address lendgine = LendgineAddress.computeAddress(0xb0C7E6bC7577706F766efA012f6604919056D0f7, 0x471EcE3750Da237f93B8E339c536989b8978a438, 0x765DE816845861e75A25fCA122bb6898B8B1282a, 2.5 ether);

        // console2.log(Lendgine(lendgine).pair());
    }
}

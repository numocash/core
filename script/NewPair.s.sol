// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";
import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";

contract DeployScript is Script {
    function run() public {
        address factory = 0x2A4a8ea165aa1d7F45d7ac03BFd6Fa58F9F5F8CC;

        address base = 0x471EcE3750Da237f93B8E339c536989b8978a438;
        address speculative = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
        uint256 upperBound = 5 ether;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        (address lendgine, address pair) = Factory(factory).createLendgine(base, speculative, 18, 18, upperBound);

        console2.log("lendgine", lendgine);
        console2.log("pair", pair);
    }
}

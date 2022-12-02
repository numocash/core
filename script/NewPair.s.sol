// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract DeployScript is Script {
    function run() public {
        address factory = 0xd7a59E4D53f08AE80F8776044A764d97cd96DEcB;
        address base = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        address speculative = 0x6C2C06790b3E3E3c38e12Ee22F8183b37a13EE55;
        uint256 upperBound = .8 ether;

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        (address lendgine, address pair) = Factory(factory).createLendgine(base, speculative, 18, 18, upperBound);

        console2.log("lendgine", lendgine);
        console2.log("pair", pair);
    }
}

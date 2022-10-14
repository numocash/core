// pragma solidity ^0.8.4;

// import "forge-std/console2.sol";

// import { TestHelper } from "./utils/TestHelper.sol";
// import { CallbackHelper } from "./utils/CallbackHelper.sol";

// import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
// import { Position } from "../src/libraries/Position.sol";

// import { Factory } from "../src/Factory.sol";
// import { Lendgine } from "../src/Lendgine.sol";

// contract CollectTest is TestHelper {
//     bytes32 public positionID;

//     function setUp() public {
//         _setUp();

//         _mintMaker(1 ether, 8 ether, 1 ether, 1, cuh);
//         _mint(1 ether, cuh);

//         positionID = Position.getID(cuh, 1);
//     }

//     function testCollect() public {
//         vm.warp(1 days + 1);

//         vm.prank(cuh);
//         lendgine.accruePositionInterest(1);

//         uint256 dilution = 0.1 ether / 10000;

//         vm.prank(cuh);
//         lendgine.collect(cuh, 1, (dilution * 10));

//         // Test lendgine token
//         assertEq(lendgine.totalSupply(), 0.1 ether);
//         assertEq(lendgine.balanceOf(cuh), 0.1 ether);
//         assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

//         assertEq(speculative.totalSupply(), 9 ether);
//         assertEq(speculative.balanceOf(cuh), (dilution * 10));
//         assertEq(speculative.balanceOf(address(lendgine)), 1 ether - (dilution * 10));

//         (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(positionID);

//         assertEq(liquidity, 1 ether);
//         assertEq(rewardPerLiquidityPaid, (dilution * 10));
//         assertEq(tokensOwed, 0);

//         (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

//         assertEq(tickLiquidity, 1 ether);
//         assertEq(rewardPerINPaid, (dilution * 10 * 10));
//         assertEq(tokensOwedPerLiquidity, (dilution * 10));

//         // Test global storage values
//         assertEq(lendgine.currentTick(), 1);
//         assertEq(lendgine.currentLiquidity(), 0.1 ether - dilution);
//         assertEq(lendgine.rewardPerINStored(), (dilution * 10 * 10));
//         assertEq(lendgine.lastUpdate(), 1 days + 1);
//     }
// }

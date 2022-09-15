// pragma solidity ^0.8.4;

// import "forge-std/console2.sol";

// import { TestHelper } from "./utils/TestHelper.sol";
// import { MintCallbackHelper } from "./utils/MintCallbackHelper.sol";

// import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
// import { Position } from "../src/libraries/Position.sol";

// import { Factory } from "../src/Factory.sol";
// import { Lendgine } from "../src/Lendgine.sol";

// contract AccrueInterestTest is TestHelper, MintCallbackHelper {
//     bytes32 public positionID;

//     function setUp() public {
//         _setUp();

//         pair.mint(cuh, 2 ether);

//         vm.prank(cuh);
//         pair.approve(address(this), 2 ether);
//         lendgine.mintMaker(cuh, 2 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

//         positionID = Position.getId(cuh);
//     }

//     function testAccrueInterestBasic() public {
//         lendgine.accrueInterest();

//         (
//             bytes32 next,
//             bytes32 previous,
//             uint256 liquidity,
//             uint256 tokensOwed,
//             uint256 rewardPerTokenPaid,
//             bool utilized
//         ) = lendgine.positions(positionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 2 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, false);

//         assertEq(lendgine.lastPosition(), positionID);
//         assertEq(lendgine.currentPosition(), positionID);
//         assertEq(lendgine.currentLiquidity(), 0);
//         assertEq(lendgine.rewardPerTokenStored(), 0);
//         assertEq(lendgine.lastUpdate(), 1);

//         assertEq(pair.balanceOf(address(lendgine)), 2 ether);
//         assertEq(pair.balanceOf(cuh), 0 ether);
//         assertEq(pair.totalSupply(), 2 ether);
//     }

//     function testAccrueInterstNoTime() public {
//         speculative.mint(cuh, 1 ether);

//         vm.prank(cuh);
//         speculative.approve(address(this), 1 ether);
//         lendgine.mint(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

//         lendgine.accrueInterest();

//         // Test lendgine token
//         assertEq(lendgine.totalSupply(), 0.1 ether);
//         assertEq(lendgine.balanceOf(cuh), 0.1 ether);
//         assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

//         // Test base token
//         assertEq(speculative.balanceOf(cuh), 0);
//         assertEq(speculative.balanceOf(address(lendgine)), 1 ether);

//         // Test position
//         (
//             bytes32 next,
//             bytes32 previous,
//             uint256 liquidity,
//             uint256 tokensOwed,
//             uint256 rewardPerTokenPaid,
//             bool utilized
//         ) = lendgine.positions(positionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 2 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, true);

//         // Test global storage values
//         assertEq(lendgine.lastPosition(), positionID);
//         assertEq(lendgine.currentPosition(), positionID);
//         assertEq(lendgine.currentLiquidity(), 0.1 ether);
//         assertEq(lendgine.rewardPerTokenStored(), 0);
//         assertEq(lendgine.lastUpdate(), 1);
//     }

//     function testAccrueInterstTime() public {
//         speculative.mint(cuh, 1 ether);

//         vm.prank(cuh);
//         speculative.approve(address(this), 1 ether);
//         lendgine.mint(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

//         vm.warp(1 days + 1);

//         lendgine.accrueInterest();
//         lendgine.accrueMakerInterest(positionID);

//         uint256 dilution = (lendgine.RATE() * 0.1 ether) / 10000;

//         // Test lendgine token
//         assertEq(lendgine.totalSupply(), 0.1 ether);
//         assertEq(lendgine.balanceOf(cuh), 0.1 ether);
//         assertEq(lendgine.balanceOf(address(lendgine)), 0 ether);

//         // Test base token
//         assertEq(speculative.balanceOf(cuh), 0);
//         assertEq(speculative.balanceOf(address(lendgine)), 1 ether);

//         (
//             bytes32 next,
//             bytes32 previous,
//             uint256 liquidity,
//             uint256 tokensOwed,
//             uint256 rewardPerTokenPaid,
//             bool utilized
//         ) = lendgine.positions(positionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 2 ether);
//         assertEq(tokensOwed, dilution * 10);
//         assertEq(rewardPerTokenPaid, (dilution * 10 * 1 ether) / (0.1 ether));
//         assertEq(utilized, true);

//         // Test global storage values
//         assertEq(lendgine.lastPosition(), positionID);
//         assertEq(lendgine.currentPosition(), positionID);
//         assertEq(lendgine.currentLiquidity(), 0.1 ether - dilution);
//         assertEq(lendgine.rewardPerTokenStored(), (dilution * 10 * 1 ether) / (0.1 ether));
//         assertEq(lendgine.lastUpdate(), 1 days + 1);
//     }

//     // withdraw and receive correct amount
// }

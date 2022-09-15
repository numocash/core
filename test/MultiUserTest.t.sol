// pragma solidity ^0.8.4;

// import "forge-std/console2.sol";

// import { TestHelper } from "./utils/TestHelper.sol";
// import { MintCallbackHelper } from "./utils/MintCallbackHelper.sol";

// import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
// import { Position } from "../src/libraries/Position.sol";

// import { Factory } from "../src/Factory.sol";
// import { Lendgine } from "../src/Lendgine.sol";

// contract MultiUserTest is TestHelper, MintCallbackHelper {
//     function setUp() public {
//         _setUp();

//         speculative.mint(address(this), 20 ether);

//         pair.mint(cuh, 2 ether);
//         pair.mint(dennis, 2 ether);
//     }

//     function testDoubleMintMaker() public {
//         vm.prank(cuh);
//         pair.approve(address(this), 2 ether);

//         vm.prank(dennis);
//         pair.approve(address(this), 2 ether);

//         lendgine.mintMaker(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
//         lendgine.mintMaker(
//             dennis,
//             1 ether,
//             abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: dennis }))
//         );

//         bytes32 cuhPositionID = Position.getId(cuh);
//         bytes32 dennisPositionID = Position.getId(dennis);

//         bytes32 next;
//         bytes32 previous;
//         uint256 liquidity;
//         uint256 tokensOwed;
//         uint256 rewardPerTokenPaid;
//         bool utilized;

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

//         assertEq(next, dennisPositionID);
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 1 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, false);

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, cuhPositionID);
//         assertEq(liquidity, 1 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, false);

//         assertEq(lendgine.lastPosition(), dennisPositionID);
//         assertEq(lendgine.currentPosition(), cuhPositionID);
//         assertEq(lendgine.currentLiquidity(), 0);
//         assertEq(lendgine.rewardPerTokenStored(), 0);
//         assertEq(lendgine.lastUpdate(), 0);

//         assertEq(pair.balanceOf(address(lendgine)), 2 ether);
//         assertEq(pair.balanceOf(cuh), 1 ether);
//         assertEq(pair.balanceOf(dennis), 1 ether);
//     }

//     function testRemoveUnutilizedMaker() public {
//         vm.prank(cuh);
//         pair.approve(address(this), 2 ether);

//         vm.prank(dennis);
//         pair.approve(address(this), 2 ether);

//         lendgine.mintMaker(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
//         lendgine.mintMaker(
//             dennis,
//             1 ether,
//             abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: dennis }))
//         );

//         vm.prank(cuh);
//         lendgine.burnMaker(cuh, 1 ether);

//         bytes32 cuhPositionID = Position.getId(cuh);
//         bytes32 dennisPositionID = Position.getId(dennis);

//         bytes32 next;
//         bytes32 previous;
//         uint256 liquidity;
//         uint256 tokensOwed;
//         uint256 rewardPerTokenPaid;
//         bool utilized;

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 0 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, false);

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 1 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, false);

//         assertEq(lendgine.lastPosition(), dennisPositionID);
//         assertEq(lendgine.currentPosition(), dennisPositionID);
//         assertEq(lendgine.currentLiquidity(), 0);
//         assertEq(lendgine.rewardPerTokenStored(), 0);
//         assertEq(lendgine.lastUpdate(), 0);

//         assertEq(pair.balanceOf(address(lendgine)), 1 ether);
//         assertEq(pair.balanceOf(cuh), 2 ether);
//         assertEq(pair.balanceOf(dennis), 1 ether);
//     }

//     function testPartialRemoveUtilizedMaker() public {
//         vm.prank(cuh);
//         pair.approve(address(this), 2 ether);

//         vm.prank(dennis);
//         pair.approve(address(this), 2 ether);

//         lendgine.mintMaker(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
//         lendgine.mintMaker(
//             dennis,
//             1 ether,
//             abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: dennis }))
//         );

//         lendgine.mint(
//             address(this),
//             10 ether,
//             abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: address(this) }))
//         );

//         vm.prank(cuh);
//         lendgine.burnMaker(cuh, 0.5 ether); // burn half of position

//         bytes32 cuhPositionID = Position.getId(cuh);
//         bytes32 dennisPositionID = Position.getId(dennis);

//         bytes32 next;
//         bytes32 previous;
//         uint256 liquidity;
//         uint256 tokensOwed;
//         uint256 rewardPerTokenPaid;
//         bool utilized;

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

//         assertEq(next, dennisPositionID);
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 0.5 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, true);

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, cuhPositionID);
//         assertEq(liquidity, 1 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, true);

//         assertEq(lendgine.lastPosition(), dennisPositionID);
//         assertEq(lendgine.currentPosition(), dennisPositionID);
//         assertEq(lendgine.currentLiquidity(), 0.5 ether);
//         assertEq(lendgine.rewardPerTokenStored(), 0);
//         assertEq(lendgine.lastUpdate(), 1);

//         assertEq(pair.balanceOf(address(this)), 1 ether);
//         assertEq(pair.balanceOf(cuh), 1.5 ether);
//         assertEq(pair.balanceOf(address(lendgine)), .5 ether);
//         assertEq(pair.balanceOf(dennis), 1 ether);
//         assertEq(pair.totalSupply(), 4 ether);
//     }

//     function testFullRemoveUtilizedMaker() public {
//         vm.prank(cuh);
//         pair.approve(address(this), 2 ether);

//         vm.prank(dennis);
//         pair.approve(address(this), 2 ether);

//         lendgine.mintMaker(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
//         lendgine.mintMaker(
//             dennis,
//             1 ether,
//             abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: dennis }))
//         );

//         lendgine.mint(
//             address(this),
//             10 ether,
//             abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: address(this) }))
//         );

//         vm.prank(cuh);
//         lendgine.burnMaker(cuh, 1 ether); // burn full position

//         bytes32 cuhPositionID = Position.getId(cuh);
//         bytes32 dennisPositionID = Position.getId(dennis);

//         bytes32 next;
//         bytes32 previous;
//         uint256 liquidity;
//         uint256 tokensOwed;
//         uint256 rewardPerTokenPaid;
//         bool utilized;

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 0 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, false);

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 1 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, true);

//         assertEq(lendgine.lastPosition(), dennisPositionID);
//         assertEq(lendgine.currentPosition(), dennisPositionID);
//         assertEq(lendgine.currentLiquidity(), 1 ether);
//         assertEq(lendgine.rewardPerTokenStored(), 0);
//         assertEq(lendgine.lastUpdate(), 1);

//         assertEq(pair.balanceOf(address(this)), 1 ether);
//         assertEq(pair.balanceOf(cuh), 2 ether);
//         assertEq(pair.balanceOf(address(lendgine)), 0 ether);
//         assertEq(pair.balanceOf(dennis), 1 ether);
//         assertEq(pair.totalSupply(), 4 ether);
//     }

//     function testMintUnutilizedMaker() public {
//         vm.prank(cuh);
//         pair.approve(address(this), 2 ether);

//         vm.prank(dennis);
//         pair.approve(address(this), 2 ether);

//         lendgine.mintMaker(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
//         lendgine.mintMaker(
//             dennis,
//             1 ether,
//             abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: dennis }))
//         );
//         lendgine.mintMaker(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

//         bytes32 cuhPositionID = Position.getId(cuh);
//         bytes32 dennisPositionID = Position.getId(dennis);

//         bytes32 next;
//         bytes32 previous;
//         uint256 liquidity;
//         uint256 tokensOwed;
//         uint256 rewardPerTokenPaid;
//         bool utilized;

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, dennisPositionID);
//         assertEq(liquidity, 2 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, false);

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

//         assertEq(next, cuhPositionID);
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 1 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, false);

//         assertEq(lendgine.lastPosition(), cuhPositionID);
//         assertEq(lendgine.currentPosition(), dennisPositionID);
//         assertEq(lendgine.currentLiquidity(), 0 ether);
//         assertEq(lendgine.rewardPerTokenStored(), 0);
//         assertEq(lendgine.lastUpdate(), 0);

//         assertEq(pair.balanceOf(address(lendgine)), 3 ether);
//         assertEq(pair.balanceOf(cuh), 0 ether);
//         assertEq(pair.balanceOf(dennis), 1 ether);
//     }

//     function testMintUtilizedMaker() public {
//         vm.prank(cuh);
//         pair.approve(address(this), 2 ether);

//         vm.prank(dennis);
//         pair.approve(address(this), 2 ether);

//         lendgine.mintMaker(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));
//         lendgine.mintMaker(
//             dennis,
//             1 ether,
//             abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: dennis }))
//         );
//         lendgine.mint(
//             address(this),
//             10 ether,
//             abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: address(this) }))
//         );
//         lendgine.mintMaker(cuh, 1 ether, abi.encode(MintCallbackHelper.MintCallbackData({ key: key, payer: cuh })));

//         bytes32 cuhPositionID = Position.getId(cuh);
//         bytes32 dennisPositionID = Position.getId(dennis);

//         bytes32 next;
//         bytes32 previous;
//         uint256 liquidity;
//         uint256 tokensOwed;
//         uint256 rewardPerTokenPaid;
//         bool utilized;

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(cuhPositionID);

//         assertEq(next, bytes32(0));
//         assertEq(previous, dennisPositionID);
//         assertEq(liquidity, 2 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, false);

//         (next, previous, liquidity, tokensOwed, rewardPerTokenPaid, utilized) = lendgine.positions(dennisPositionID);

//         assertEq(next, cuhPositionID);
//         assertEq(previous, bytes32(0));
//         assertEq(liquidity, 1 ether);
//         assertEq(tokensOwed, 0);
//         assertEq(rewardPerTokenPaid, 0);
//         assertEq(utilized, true);

//         assertEq(lendgine.lastPosition(), cuhPositionID);
//         assertEq(lendgine.currentPosition(), dennisPositionID);
//         assertEq(lendgine.currentLiquidity(), 1 ether);
//         assertEq(lendgine.rewardPerTokenStored(), 0);
//         assertEq(lendgine.lastUpdate(), 1);

//         assertEq(pair.balanceOf(address(this)), 1 ether);
//         assertEq(pair.balanceOf(address(lendgine)), 2 ether);
//         assertEq(pair.balanceOf(cuh), 0 ether);
//         assertEq(pair.balanceOf(dennis), 1 ether);
//     }
// }

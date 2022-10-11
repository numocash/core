pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";

import { Factory } from "../src/Factory.sol";
import { Lendgine } from "../src/Lendgine.sol";

contract MultiUserTest is TestHelper {
    function setUp() public {
        _setUp();
    }

    function testDoubleMintMakerSame() public {
        _mintMaker(1 ether, 1 ether, 1 ether, 1, cuh);
        _mintMaker(1 ether, 1 ether, 1 ether, 1, dennis);

        bytes32 cuhPositionID = Position.getId(cuh, 1);
        bytes32 dennisPositionID = Position.getId(dennis, 1);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 2 * k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.totalSupply(), 2 * k);
        assertEq(pair.buffer(), 0);
    }

    function testDoubleMintMakerDifferent() public {
        _mintMaker(1 ether, 1 ether, 1 ether, 1, cuh);
        _mintMaker(1 ether, 1 ether, 1 ether, 2, dennis);

        bytes32 cuhPositionID = Position.getId(cuh, 1);
        bytes32 dennisPositionID = Position.getId(dennis, 2);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.totalSupply(), 2 * k);
        assertEq(pair.buffer(), 0);
    }

    function testRemoveUnutilizedMaker() public {
        _mintMaker(1 ether, 1 ether, 1 ether, 1, cuh);
        _mintMaker(1 ether, 1 ether, 1 ether, 2, dennis);
        _burnMaker(k, 1, cuh);

        bytes32 cuhPositionID = Position.getId(cuh, 1);
        bytes32 dennisPositionID = Position.getId(dennis, 2);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, 0);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 0);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        // TODO: what to do about removing a current tick
        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.totalSupply(), 2 * k);
        assertEq(pair.buffer(), k);
    }

    function testPartialRemoveUtilizedMaker() public {
        _mintMaker(1 ether, 1 ether, 1 ether, 1, cuh);
        _mintMaker(1 ether, 1 ether, 1 ether, 2, dennis);
        _mint(60 ether, address(this));
        _burnMaker(k / 2, 1, cuh);

        bytes32 cuhPositionID = Position.getId(cuh, 1);
        bytes32 dennisPositionID = Position.getId(dennis, 2);

        assertEq(lendgine.balanceOf(address(this)), 6 ether * 1 ether);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, k / 2);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, k / 2);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 2);
        assertEq(lendgine.currentLiquidity(), 2.5 * 10**35 + k / 2);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 2 * k);
        assertEq(pair.buffer(), k / 2 + 6 ether * 1 ether);
    }

    function testFullRemoveUtilizedMaker() public {
        _mintMaker(1 ether, 1 ether, 1 ether, 1, cuh);
        _mintMaker(1 ether, 1 ether, 1 ether, 2, dennis);
        _mint(10 ether, address(this));
        _burnMaker(k, 1, cuh);

        bytes32 cuhPositionID = Position.getId(cuh, 1);
        bytes32 dennisPositionID = Position.getId(dennis, 2);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, 0);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 0);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 2);
        assertEq(lendgine.currentLiquidity(), 1 ether * 1 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 2 * k);
        assertEq(pair.buffer(), k + 1 ether * 1 ether);
    }

    function testMintTwoTicksMaker() public {
        _mintMaker(1 ether, 1 ether, 1 ether, 1, cuh);
        _mintMaker(1 ether, 1 ether, 1 ether, 2, dennis);
        _mint(60 ether, address(this));

        bytes32 cuhPositionID = Position.getId(cuh, 1);
        bytes32 dennisPositionID = Position.getId(dennis, 2);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 2);
        assertEq(lendgine.currentLiquidity(), 2.5 * 10**35);
        assertEq(lendgine.interestNumerator(), k + 5 * 10**35);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 2 * k);
        assertEq(pair.buffer(), 6 ether * 1 ether);
    }

    function testMintFarTicksMaker() public {
        _mintMaker(1 ether, 1 ether, 1 ether, 1, cuh);
        _mintMaker(1 ether, 1 ether, 1 ether, 10, dennis);
        _mint(60 ether, address(this));

        bytes32 cuhPositionID = Position.getId(cuh, 1);
        bytes32 dennisPositionID = Position.getId(dennis, 10);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(10);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 10);
        assertEq(lendgine.currentLiquidity(), 2.5 * 10**35);
        assertEq(lendgine.interestNumerator(), k + 25 * 10**35);

        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 2 * k);
        assertEq(pair.buffer(), 6 ether * 1 ether);
    }

    function testMintUtilizedMaker() public {
        _mintMaker(1 ether, 1 ether, 1 ether, 1, cuh);
        _mintMaker(1 ether, 1 ether, 1 ether, 2, dennis);
        _mint(60 ether, address(this));
        pair.burn(address(this));
        _mintMaker(1 ether, 1 ether, 1 ether, 1, cuh);

        bytes32 cuhPositionID = Position.getId(cuh, 1);
        bytes32 dennisPositionID = Position.getId(dennis, 2);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, 2 * k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, 2 * k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 6 * 10**36);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 3 * k - 6 ether * 1 ether);
        assertEq(pair.buffer(), 0);
    }

    function testMintNewUtilizedMaker() public {
        _mintMaker(1 ether, 1 ether, 1 ether, 2, cuh);
        _mint(30 ether, address(this));
        pair.burn(address(this));
        _mintMaker(1 ether, 1 ether, 1 ether, 1, dennis);

        bytes32 cuhPositionID = Position.getId(cuh, 2);
        bytes32 dennisPositionID = Position.getId(dennis, 1);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 3 * 10**36);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 2 * k - 3 ether * 1 ether);
        assertEq(pair.buffer(), 0);
    }

    function testRemoveTwoTicks() public {
        _mintMaker(1 ether, 1 ether, 1 ether, 1, cuh);
        _mintMaker(1 ether, 1 ether, 1 ether, 2, dennis);
        _mint(60 ether, address(this));
        _burn(3 * 10**36, address(this));

        bytes32 cuhPositionID = Position.getId(cuh, 1);
        bytes32 dennisPositionID = Position.getId(dennis, 2);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, k);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

        assertEq(tickLiquidity, k);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 3 ether * 1 ether);
        assertEq(lendgine.interestNumerator(), 3 ether * 1 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 2 * k);
        assertEq(pair.buffer(), 3 ether * 1 ether);
    }
}

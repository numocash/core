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

    function testDoubleDepositSame() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 1, dennis);

        bytes32 cuhPositionID = Position.getID(cuh, 1);
        bytes32 dennisPositionID = Position.getID(dennis, 1);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, 1 ether);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, 1 ether);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (
            uint256 tickLiquidity,
            uint256 rewardPerINPaid,
            uint256 tokensOwedPerLiquidity,
            uint16 prev,
            uint16 next
        ) = lendgine.ticks(1);

        assertEq(tickLiquidity, 2 * 1 ether);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);
        assertEq(next, 0);
        assertEq(prev, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.totalSupply(), 2 * 1 ether);
        assertEq(pair.buffer(), 0);
    }

    function testDoubleDepositDifferent() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 2, dennis);

        bytes32 cuhPositionID = Position.getID(cuh, 1);
        bytes32 dennisPositionID = Position.getID(dennis, 2);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, 1 ether);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, 1 ether);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (
            uint256 tickLiquidity,
            uint256 rewardPerINPaid,
            uint256 tokensOwedPerLiquidity,
            uint16 prev,
            uint16 next
        ) = lendgine.ticks(1);

        assertEq(tickLiquidity, 1 ether);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);
        assertEq(prev, 0);
        assertEq(next, 2);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity, prev, next) = lendgine.ticks(2);

        assertEq(tickLiquidity, 1 ether);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);
        assertEq(prev, 1);
        assertEq(next, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.totalSupply(), 2 * 1 ether);
        assertEq(pair.buffer(), 0);
    }

    function testUnutilizedWithdraw() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
        _withdraw(1 ether, 1, cuh);

        bytes32 cuhPositionID = Position.getID(cuh, 1);
        bytes32 dennisPositionID = Position.getID(dennis, 2);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, 0);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, 1 ether);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (
            uint256 tickLiquidity,
            uint256 rewardPerINPaid,
            uint256 tokensOwedPerLiquidity,
            uint16 prev,
            uint16 next
        ) = lendgine.ticks(1);

        assertEq(tickLiquidity, 0);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);
        assertEq(prev, 0);
        assertEq(next, 0);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity, prev, next) = lendgine.ticks(2);

        assertEq(tickLiquidity, 1 ether);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);
        assertEq(prev, 0);
        assertEq(next, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.totalSupply(), 2 * 1 ether);
        assertEq(pair.buffer(), 1 ether);
    }

    // function testPartialRemoveUtilizedMaker() public {
    //     _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
    //     _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
    //     _mint(10 ether, address(this));
    //     _withdraw(0.5 ether, 1, cuh);

    //     bytes32 cuhPositionID = Position.getID(cuh, 1);
    //     bytes32 dennisPositionID = Position.getID(dennis, 2);

    //     assertEq(lendgine.balanceOf(address(this)), 1 ether);

    //     (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

    //     assertEq(liquidity, 1 ether / 2);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

    //     assertEq(liquidity, 1 ether);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

    //     assertEq(tickLiquidity, 1 ether / 2);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);

    //     (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

    //     assertEq(tickLiquidity, 1 ether);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);

    //     assertEq(lendgine.currentTick(), 2);
    //     assertEq(lendgine.currentLiquidity(), 0.5 ether);
    //     assertEq(lendgine.rewardPerINStored(), 0);
    //     assertEq(lendgine.lastUpdate(), 1);
    //     assertEq(lendgine.interestNumerator(), 1.5 ether);
    //     assertEq(lendgine.totalLiquidityBorrowed(), 1 ether);

    //     assertEq(pair.totalSupply(), 2 * 1 ether);
    //     assertEq(pair.buffer(), 1.5 ether);
    // }

    // function testFullRemoveUtilizedMaker() public {
    //     _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
    //     _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
    //     _mint(10 ether, address(this));
    //     _withdraw(1 ether, 1, cuh);

    //     bytes32 cuhPositionID = Position.getID(cuh, 1);
    //     bytes32 dennisPositionID = Position.getID(dennis, 2);

    //     (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

    //     assertEq(liquidity, 0);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

    //     assertEq(liquidity, 1 ether);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

    //     assertEq(tickLiquidity, 0);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);

    //     (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

    //     assertEq(tickLiquidity, 1 ether);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);

    //     assertEq(lendgine.currentTick(), 2);
    //     assertEq(lendgine.currentLiquidity(), 1 ether);
    //     assertEq(lendgine.rewardPerINStored(), 0);
    //     assertEq(lendgine.lastUpdate(), 1);

    //     assertEq(pair.totalSupply(), 2 ether);
    //     assertEq(pair.buffer(), 1 ether + 1 ether);
    // }

    // function testMintTwoTicksMaker() public {
    //     _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
    //     _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
    //     _mint(15 ether, address(this));

    //     bytes32 cuhPositionID = Position.getID(cuh, 1);
    //     bytes32 dennisPositionID = Position.getID(dennis, 2);

    //     (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

    //     assertEq(liquidity, 1 ether);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

    //     assertEq(liquidity, 1 ether);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

    //     assertEq(tickLiquidity, 1 ether);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);

    //     (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

    //     assertEq(tickLiquidity, 1 ether);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);

    //     assertEq(lendgine.currentTick(), 2);
    //     assertEq(lendgine.currentLiquidity(), 0.5 ether);
    //     assertEq(lendgine.interestNumerator(), 2 ether);
    //     assertEq(lendgine.rewardPerINStored(), 0);
    //     assertEq(lendgine.lastUpdate(), 1);

    //     assertEq(pair.totalSupply(), 2 * 1 ether);
    //     assertEq(pair.buffer(), 1.5 ether);
    // }

    // function testMintFarTicksMaker() public {
    //     _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
    //     _deposit(1 ether, 8 ether, 1 ether, 10, dennis);
    //     _mint(15 ether, address(this));

    //     bytes32 cuhPositionID = Position.getID(cuh, 1);
    //     bytes32 dennisPositionID = Position.getID(dennis, 10);

    //     (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

    //     assertEq(liquidity, 1 ether);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

    //     assertEq(liquidity, 1 ether);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

    //     assertEq(tickLiquidity, 1 ether);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);

    //     (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(10);

    //     assertEq(tickLiquidity, 1 ether);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);

    //     assertEq(lendgine.currentTick(), 10);
    //     assertEq(lendgine.currentLiquidity(), 0.5 ether);
    //     assertEq(lendgine.interestNumerator(), 6 ether);

    //     assertEq(lendgine.rewardPerINStored(), 0);
    //     assertEq(lendgine.lastUpdate(), 1);

    //     assertEq(pair.totalSupply(), 2 * 1 ether);
    //     assertEq(pair.buffer(), 1.5 ether);
    // }

    // function testMintUtilizedMaker() public {
    //     _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
    //     _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
    //     _mint(15 ether, address(this));
    //     pair.burn(address(this));
    //     _deposit(1 ether, 8 ether, 1 ether, 1, cuh);

    //     bytes32 cuhPositionID = Position.getID(cuh, 1);
    //     bytes32 dennisPositionID = Position.getID(dennis, 2);

    //     (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

    //     assertEq(liquidity, 2 * 1 ether);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

    //     assertEq(liquidity, 1 ether);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (uint256 tickLiquidity, uint256 rewardPerINPaid, uint256 tokensOwedPerLiquidity) = lendgine.ticks(1);

    //     assertEq(tickLiquidity, 2 * 1 ether);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);

    //     (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity) = lendgine.ticks(2);

    //     assertEq(tickLiquidity, 1 ether);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);

    //     assertEq(lendgine.currentTick(), 1);
    //     assertEq(lendgine.currentLiquidity(), 1.5 ether);
    //     assertEq(lendgine.rewardPerINStored(), 0);
    //     assertEq(lendgine.lastUpdate(), 1);
    //     assertEq(lendgine.totalLiquidityBorrowed(), 1.5 ether);
    //     assertEq(lendgine.interestNumerator(), 1.5 ether);

    //     assertEq(pair.totalSupply(), 1.5 ether);
    //     assertEq(pair.buffer(), 0);
    // }

    // function testMintNewUtilizedMaker() public {
    //     _deposit(1 ether, 8 ether, 1 ether, 2, cuh);
    //     _mint(5 ether, address(this));
    //     pair.burn(address(this));
    //     _deposit(1 ether, 8 ether, 1 ether, 1, dennis);

    //     bytes32 cuhPositionID = Position.getID(cuh, 2);
    //     bytes32 dennisPositionID = Position.getID(dennis, 1);

    //     (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

    //     assertEq(liquidity, 1 ether);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

    //     assertEq(liquidity, 1 ether);
    //     assertEq(rewardPerLiquidityPaid, 0);
    //     assertEq(tokensOwed, 0);

    //     (
    //         uint256 tickLiquidity,
    //         uint256 rewardPerINPaid,
    //         uint256 tokensOwedPerLiquidity,
    //         uint16 prev,
    //         uint16 next
    //     ) = lendgine.ticks(1);

    //     assertEq(tickLiquidity, 1 ether);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);
    //     // assertEq(prev, 0);
    //     // assertEq(next, 2);

    //     (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity, prev, next) = lendgine.ticks(2);

    //     assertEq(tickLiquidity, 1 ether);
    //     assertEq(rewardPerINPaid, 0);
    //     assertEq(tokensOwedPerLiquidity, 0);
    //     assertEq(prev, 1);
    //     assertEq(next, 0);

    //     assertEq(lendgine.currentTick(), 1);
    //     assertEq(lendgine.currentLiquidity(), 0.5 ether);
    //     assertEq(lendgine.rewardPerINStored(), 0);
    //     assertEq(lendgine.lastUpdate(), 1);

    //     assertEq(pair.totalSupply(), 1.5 ether);
    //     assertEq(pair.buffer(), 0);
    // }

    function testRemoveTwoTicks() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
        _mint(15 ether, address(this));
        _burn(1 ether, address(this));

        bytes32 cuhPositionID = Position.getID(cuh, 1);
        bytes32 dennisPositionID = Position.getID(dennis, 2);

        (uint256 liquidity, uint256 rewardPerLiquidityPaid, uint256 tokensOwed) = lendgine.positions(cuhPositionID);

        assertEq(liquidity, 1 ether);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (liquidity, rewardPerLiquidityPaid, tokensOwed) = lendgine.positions(dennisPositionID);

        assertEq(liquidity, 1 ether);
        assertEq(rewardPerLiquidityPaid, 0);
        assertEq(tokensOwed, 0);

        (
            uint256 tickLiquidity,
            uint256 rewardPerINPaid,
            uint256 tokensOwedPerLiquidity,
            uint16 prev,
            uint16 next
        ) = lendgine.ticks(1);

        assertEq(tickLiquidity, 1 ether);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);
        assertEq(prev, 0);
        assertEq(next, 2);

        (tickLiquidity, rewardPerINPaid, tokensOwedPerLiquidity, prev, next) = lendgine.ticks(2);

        assertEq(tickLiquidity, 1 ether);
        assertEq(rewardPerINPaid, 0);
        assertEq(tokensOwedPerLiquidity, 0);
        assertEq(prev, 1);
        assertEq(next, 0);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0.5 ether);
        assertEq(lendgine.interestNumerator(), 0.5 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 2 * 1 ether);
        assertEq(pair.buffer(), 0.5 ether);
    }

    function testRemoveSharedTick() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 1, dennis);
        _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
        _mint(10 ether, address(this));
        _withdraw(0.5 ether, 1, cuh);

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 1 ether);
        assertEq(lendgine.interestNumerator(), 1 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.totalLiquidityBorrowed(), 1 ether);
    }
}

pragma solidity ^0.8.4;

import "forge-std/console2.sol";

import { TestHelper } from "./utils/TestHelper.sol";
import { CallbackHelper } from "./utils/CallbackHelper.sol";

import { LendgineAddress } from "../src/libraries/LendgineAddress.sol";
import { Position } from "../src/libraries/Position.sol";
import { Tick } from "../src/libraries/Tick.sol";

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

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuhPositionID);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            dennisPositionID
        );

        assertTick(
            Tick.Info({ liquidity: 2 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }),
            1
        );

        assertEq(lendgine.currentTick(), 0);
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

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuhPositionID);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            dennisPositionID
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 2 }),
            1
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 1, next: 0 }),
            2
        );

        assertEq(lendgine.currentTick(), 0);
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

        assertPosition(Position.Info({ liquidity: 0, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuhPositionID);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            dennisPositionID
        );

        assertTick(
            Tick.Info({ liquidity: 0 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }),
            1
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }),
            2
        );
        assertEq(lendgine.currentTick(), 0);
        assertEq(lendgine.currentLiquidity(), 0);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 0);

        assertEq(pair.totalSupply(), 2 * 1 ether);
        assertEq(pair.buffer(), 1 ether);
    }

    function testPartialRemoveUtilizedMaker() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
        _mint(10 ether, address(this));
        _withdraw(0.5 ether, 1, cuh);

        bytes32 cuhPositionID = Position.getID(cuh, 1);
        bytes32 dennisPositionID = Position.getID(dennis, 2);

        assertEq(lendgine.balanceOf(address(this)), 1 ether);

        assertPosition(
            Position.Info({ liquidity: 0.5 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            cuhPositionID
        );

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            dennisPositionID
        );

        assertTick(
            Tick.Info({ liquidity: 0.5 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 2 }),
            1
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 1, next: 0 }),
            2
        );
        assertEq(lendgine.currentTick(), 2);
        assertEq(lendgine.currentLiquidity(), 0.5 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.interestNumerator(), 1.5 ether);
        assertEq(lendgine.totalLiquidityBorrowed(), 1 ether);

        assertEq(pair.totalSupply(), 2 * 1 ether);
        assertEq(pair.buffer(), 1.5 ether);
    }

    function testFullRemoveUtilizedMaker() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
        _mint(10 ether, address(this));
        _withdraw(1 ether, 1, cuh);

        bytes32 cuhPositionID = Position.getID(cuh, 1);
        bytes32 dennisPositionID = Position.getID(dennis, 2);

        assertPosition(Position.Info({ liquidity: 0, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuhPositionID);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            dennisPositionID
        );

        assertTick(Tick.Info({ liquidity: 0, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }), 1);

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 0 }),
            2
        );

        assertEq(lendgine.currentTick(), 2);
        assertEq(lendgine.currentLiquidity(), 1 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 2 ether);
        assertEq(pair.buffer(), 1 ether + 1 ether);
    }

    function testMintTwoTicksMaker() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
        _mint(15 ether, address(this));

        bytes32 cuhPositionID = Position.getID(cuh, 1);
        bytes32 dennisPositionID = Position.getID(dennis, 2);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuhPositionID);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            dennisPositionID
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 2 }),
            1
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 1, next: 0 }),
            2
        );

        assertEq(lendgine.currentTick(), 2);
        assertEq(lendgine.currentLiquidity(), 0.5 ether);
        assertEq(lendgine.interestNumerator(), 2 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 2 * 1 ether);
        assertEq(pair.buffer(), 1.5 ether);
    }

    function testMintFarTicksMaker() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 10, dennis);
        _mint(15 ether, address(this));

        bytes32 cuhPositionID = Position.getID(cuh, 1);
        bytes32 dennisPositionID = Position.getID(dennis, 10);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuhPositionID);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            dennisPositionID
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 10 }),
            1
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 1, next: 0 }),
            10
        );

        assertEq(lendgine.currentTick(), 10);
        assertEq(lendgine.currentLiquidity(), 0.5 ether);
        assertEq(lendgine.interestNumerator(), 6 ether);

        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 2 * 1 ether);
        assertEq(pair.buffer(), 1.5 ether);
    }

    function testMintUtilizedMaker() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
        _mint(15 ether, address(this));
        pair.burn(address(this));
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);

        bytes32 cuhPositionID = Position.getID(cuh, 1);
        bytes32 dennisPositionID = Position.getID(dennis, 2);

        assertPosition(Position.Info({ liquidity: 2 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuhPositionID);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            dennisPositionID
        );

        assertTick(
            Tick.Info({ liquidity: 2 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 2 }),
            1
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 1, next: 0 }),
            2
        );

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 1.5 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);
        assertEq(lendgine.totalLiquidityBorrowed(), 1.5 ether);
        assertEq(lendgine.interestNumerator(), 1.5 ether);

        assertEq(pair.totalSupply(), 1.5 ether);
        assertEq(pair.buffer(), 0);
    }

    function testMintNewUtilizedMaker() public {
        _deposit(1 ether, 8 ether, 1 ether, 2, cuh);
        _mint(5 ether, address(this));
        pair.burn(address(this));
        _deposit(1 ether, 8 ether, 1 ether, 1, dennis);

        bytes32 cuhPositionID = Position.getID(cuh, 2);
        bytes32 dennisPositionID = Position.getID(dennis, 1);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuhPositionID);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            dennisPositionID
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 2 }),
            1
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 1, next: 0 }),
            2
        );

        assertEq(lendgine.currentTick(), 1);
        assertEq(lendgine.currentLiquidity(), 0.5 ether);
        assertEq(lendgine.rewardPerINStored(), 0);
        assertEq(lendgine.lastUpdate(), 1);

        assertEq(pair.totalSupply(), 1.5 ether);
        assertEq(pair.buffer(), 0);
    }

    function testRemoveTwoTicks() public {
        _deposit(1 ether, 8 ether, 1 ether, 1, cuh);
        _deposit(1 ether, 8 ether, 1 ether, 2, dennis);
        _mint(15 ether, address(this));
        _burn(1 ether, address(this));

        bytes32 cuhPositionID = Position.getID(cuh, 1);
        bytes32 dennisPositionID = Position.getID(dennis, 2);

        assertPosition(Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }), cuhPositionID);

        assertPosition(
            Position.Info({ liquidity: 1 ether, rewardPerLiquidityPaid: 0, tokensOwed: 0 }),
            dennisPositionID
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 0, next: 2 }),
            1
        );

        assertTick(
            Tick.Info({ liquidity: 1 ether, rewardPerINPaid: 0, tokensOwedPerLiquidity: 0, prev: 1, next: 0 }),
            2
        );

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

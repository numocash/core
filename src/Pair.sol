// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Factory } from "./Factory.sol";
import { Lendgine } from "./Lendgine.sol";

import { IPair } from "./interfaces/IPair.sol";

import { SafeTransferLib } from "./libraries/SafeTransferLib.sol";

contract Pair is IPair {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Mint(address indexed sender, uint256 liquidity);

    event Burn(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);

    event Swap(address indexed sender, uint256 amount0Out, uint256 amount1Out, address indexed to);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ReentrancyError();

    error InsufficientInputError();

    error InsufficientOutputError();

    error BalanceReturnError();

    error LendgineError();

    error InvariantError();

    error BaseInvariantError();

    error SpeculativeInvariantError();

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPair
    address public immutable override factory;

    /// @inheritdoc IPair
    address public immutable override lendgine;

    /// @inheritdoc IPair
    address public immutable override base;

    /// @inheritdoc IPair
    address public immutable override speculative;

    /// @inheritdoc IPair
    uint256 public immutable override upperBound;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPair
    uint256 public override totalSupply;

    /// @inheritdoc IPair
    uint256 public override buffer;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _factory) {
        lendgine = msg.sender;
        factory = _factory;
        (base, speculative, upperBound) = Factory(factory).parameters();
    }

    /*//////////////////////////////////////////////////////////////
                              PAIR LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPair
    function verifyInvariant(
        uint256 r0,
        uint256 r1,
        uint256 shares
    ) public view returns (bool valid) {
        uint256 scale0 = (r0 * 10**18) / shares;
        uint256 scale1 = (r1 * 10**18) / shares;

        uint256 a = scale0 * 10**18;
        uint256 b = upperBound * scale1;
        uint256 c = (scale1**2) / 4;
        uint256 d = upperBound**2;

        if (a > d) revert BaseInvariantError();
        if (scale1 > 2 * upperBound) revert SpeculativeInvariantError();

        return a + b == c + d;
    }

    /// @inheritdoc IPair
    function mint(uint256 liquidity) external override {
        if (liquidity == 0) revert InsufficientOutputError();

        (uint256 balance0, uint256 balance1) = balances();
        if (!verifyInvariant(balance0, balance1, liquidity + totalSupply)) revert InvariantError();
        _mint(liquidity);

        emit Mint(msg.sender, liquidity);
    }

    /// @inheritdoc IPair
    function burn(
        address to,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    ) external override {
        if (!verifyInvariant(amount0, amount1, liquidity)) revert InvariantError();

        if (amount0 == 0 && amount1 == 0) revert InsufficientOutputError();
        _burn(liquidity);

        SafeTransferLib.safeTransfer(base, to, amount0);
        SafeTransferLib.safeTransfer(speculative, to, amount1);

        emit Burn(msg.sender, amount0, amount1, liquidity, to);
    }

    /// @inheritdoc IPair
    function swap(
        address to,
        uint256 amount0Out,
        uint256 amount1Out
    ) external override {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputError();

        if (amount0Out > 0) SafeTransferLib.safeTransfer(base, to, amount0Out);
        if (amount1Out > 0) SafeTransferLib.safeTransfer(speculative, to, amount1Out);

        (uint256 balance0, uint256 balance1) = balances();
        if (!verifyInvariant(balance0, balance1, totalSupply)) revert InvariantError();

        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPair
    function balances() public view override returns (uint256, uint256) {
        bool success;
        bytes memory data;

        (success, data) = base.staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("balanceOf(address)"))), address(this))
        );
        if (!success || data.length < 32) revert BalanceReturnError();
        uint256 balance0 = abi.decode(data, (uint256));

        (success, data) = speculative.staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("balanceOf(address)"))), address(this))
        );
        if (!success || data.length < 32) revert BalanceReturnError();

        return (balance0, abi.decode(data, (uint256)));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(uint256 amount) internal {
        totalSupply += amount;

        // Cannot overflow because the buffer
        // can't exceed the max uint256 value.
        unchecked {
            buffer += amount;
        }
    }

    function _burn(uint256 amount) internal {
        buffer -= amount;

        // Cannot underflow because the buffer
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }
    }

    /*//////////////////////////////////////////////////////////////
                             BUFFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPair
    function addBuffer(uint256 amount) external override {
        if (msg.sender != lendgine) revert LendgineError();

        buffer += amount;
    }

    /// @inheritdoc IPair
    function removeBuffer(uint256 amount) external override {
        if (msg.sender != lendgine) revert LendgineError();

        buffer -= amount;
    }
}

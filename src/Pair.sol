// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "./Factory.sol";
import { Lendgine } from "./Lendgine.sol";

import { IPairMintCallback } from "./interfaces/IPairMintCallback.sol";
import { ISwapCallback } from "./interfaces/ISwapCallback.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

/// @notice A gas efficient and opinionated capped power invariant pair
/// @author Kyle Scott (https://github.com/numoen/core/blob/master/src/Pair.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol)
/// Primitive (https://github.com/primitivefinance/rmm-core/blob/main/contracts/PrimitiveEngine.sol),
/// and Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
contract Pair {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Mint(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity);

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

    address public immutable factory;

    address public immutable lendgine;

    address public immutable base;

    address public immutable speculative;

    uint256 public immutable upperBound;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    uint256 public buffer;

    /*//////////////////////////////////////////////////////////////
                           REENTRANCY LOGIC
    //////////////////////////////////////////////////////////////*/

    uint256 private locked = 1;

    modifier lock() virtual {
        if (locked != 1) revert ReentrancyError();

        locked = 2;

        _;

        locked = 1;
    }

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

    function verifyInvariant(
        uint256 r0,
        uint256 r1,
        uint256 shares
    ) public view returns (bool) {
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

    function mint(
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity,
        bytes calldata data
    ) external lock {
        if (liquidity == 0) revert InsufficientOutputError();

        (uint256 balance0Before, uint256 balance1Before) = balances();
        if (!verifyInvariant(amount0, amount1, liquidity)) revert InvariantError();

        _mint(liquidity); // optimistic mint

        IPairMintCallback(msg.sender).PairMintCallback(amount0, amount1, data);

        (uint256 balance0After, uint256 balance1After) = balances();

        if (balance0After - balance0Before < amount0) revert InsufficientInputError();
        if (balance1After - balance1Before < amount1) revert InsufficientInputError();

        emit Mint(msg.sender, amount0, amount1, liquidity);
    }

    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint256 balance0, uint256 balance1) = balances();
        uint256 liquidity = buffer;
        uint256 _totalSupply = totalSupply;

        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;

        if (amount0 == 0 && amount1 == 0) revert InsufficientOutputError();
        _burn(liquidity);

        SafeTransferLib.safeTransfer(ERC20(base), to, amount0);
        SafeTransferLib.safeTransfer(ERC20(speculative), to, amount1);

        emit Burn(msg.sender, amount0, amount1, liquidity, to);
    }

    function swap(
        address to,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external lock {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputError();

        if (amount0Out > 0) SafeTransferLib.safeTransfer(ERC20(base), to, amount0Out);
        if (amount1Out > 0) SafeTransferLib.safeTransfer(ERC20(speculative), to, amount1Out);

        ISwapCallback(msg.sender).SwapCallback(amount0Out, amount1Out, data);

        (uint256 balance0, uint256 balance1) = balances();
        if (!verifyInvariant(balance0, balance1, totalSupply)) revert InvariantError();

        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    function balances() public view returns (uint256, uint256) {
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

    function lendgineBalance() external view returns (uint256) {
        uint256 _totalSupply = totalSupply; // SLOAD for gas optimization
        if (_totalSupply == 0) return 0;

        return _totalSupply - buffer;
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

    function addBuffer(uint256 amount) external {
        if (msg.sender != lendgine) revert LendgineError();

        buffer += amount;
    }

    function removeBuffer(uint256 amount) external {
        if (msg.sender != lendgine) revert LendgineError();

        buffer -= amount;
    }
}

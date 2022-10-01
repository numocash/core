// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "./Factory.sol";
import { Lendgine } from "./Lendgine.sol";

import { IPairMintCallback } from "./interfaces/IPairMintCallback.sol";
import { ISwapCallback } from "./interfaces/ISwapCallback.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import "forge-std/console2.sol";

/// @notice A general purpose and gas efficient CFMM pair
/// @author Kyle Scott (https://github.com/kyscott18/kyleswap2.5/blob/main/src/Pair.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol)
/// and Primitive (https://github.com/primitivefinance/rmm-core/blob/main/contracts/PrimitiveEngine.sol), and Solmate
contract Pair {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Mint(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity);

    event Burn(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);

    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ReentrancyError();

    error InsufficientInputError();

    error InsufficientOutputError();

    error BalanceReturnError();

    error LendgineError();

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable factory;

    address public immutable lendgine;

    address public immutable token0;

    address public immutable token1;

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
        (token0, token1, upperBound) = Factory(factory).parameters();
    }

    /*//////////////////////////////////////////////////////////////
                              PAIR LOGIC
    //////////////////////////////////////////////////////////////*/

    function calcInvariant(uint256 r0, uint256 r1) public view returns (uint256 invariant) {
        // console2.log("a", r0 + (upperBound * r1) / 1 ether);
        // console2.log("b", (r1**2) / 4 ether);
        invariant = 10**9 * r0 + (upperBound * r1) / (10**9) - (r1**2) / (4 * 10**9);
    }

    function mint(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external lock returns (uint256 liquidity) {
        (uint256 balance0Before, uint256 balance1Before) = balances();
        liquidity = calcInvariant(amount0, amount1);

        if (liquidity == 0) revert InsufficientOutputError();
        _mint(liquidity); // optimistic mint

        IPairMintCallback(msg.sender).PairMintCallback(amount0, amount1, data);

        (uint256 balance0After, uint256 balance1After) = balances();

        if (balance0After - balance0Before < amount0) revert InsufficientInputError();
        if (balance1After - balance1Before < amount1) revert InsufficientInputError();

        emit Mint(msg.sender, amount0, amount1, liquidity);
    }

    function burn(
        address to,
        uint256 amount0,
        uint256 amount1
    ) external lock returns (uint256 k) {
        if (amount0 == 0 && amount1 == 0) revert InsufficientOutputError();

        k = calcInvariant(amount0, amount1);

        _burn(k);

        SafeTransferLib.safeTransfer(ERC20(token0), to, amount0);
        SafeTransferLib.safeTransfer(ERC20(token1), to, amount1);

        emit Burn(msg.sender, amount0, amount1, k, to);
    }

    function swap(
        address to,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external lock returns (uint256 amount0In, uint256 amount1In) {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputError();

        (uint256 balance0Before, uint256 balance1Before) = balances();
        uint256 invariantBefore = calcInvariant(balance0Before, balance1Before);

        if (amount0Out > 0) SafeTransferLib.safeTransfer(ERC20(token0), to, amount0Out);
        if (amount1Out > 0) SafeTransferLib.safeTransfer(ERC20(token1), to, amount1Out);

        ISwapCallback(msg.sender).SwapCallback(amount0Out, amount1Out, data);

        {
            (uint256 balance0After, uint256 balance1After) = balances();
            amount0In = balance0After + amount0Out - balance0Before;
            amount1In = balance1After + amount1Out - balance1Before;

            uint256 invariantAfter = calcInvariant(balance0After, balance1After);
            // console2.log("IB", invariantBefore);
            // console2.log("IA", invariantAfter);
            // console2.log("dif", invariantBefore - invariantAfter);
            if (invariantBefore > invariantAfter) revert InsufficientInputError();
        }

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    function balances() public view returns (uint256, uint256) {
        bool success;
        bytes memory data;

        (success, data) = token0.staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("balanceOf(address)"))), address(this))
        );
        if (!success || data.length < 32) revert BalanceReturnError();
        uint256 balance0 = abi.decode(data, (uint256));

        (success, data) = token1.staticcall(
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

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            buffer += amount;
        }
    }

    function _burn(uint256 amount) internal {
        buffer -= amount;

        // Cannot underflow because a user's balance
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

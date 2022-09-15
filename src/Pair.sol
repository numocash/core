// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "./Factory.sol";

import { IPairMintCallback } from "./interfaces/IPairMintCallback.sol";
import { ISwapCallback } from "./interfaces/ISwapCallback.sol";

import { Math } from "./libraries/Math.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import "forge-std/console2.sol";

/// @notice A general purpose and gas efficient CFMM pair
/// @author Kyle Scott (https://github.com/kyscott18/kyleswap2.5/blob/main/src/Pair.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol)
/// and Primitive (https://github.com/primitivefinance/rmm-core/blob/main/contracts/PrimitiveEngine.sol)
contract Pair is ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Mint(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);

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

    error InvariantError();

    error InsufficientInputError();

    error InsufficientOutputError();

    error InsufficientBurnError();

    error BalanceReturnError();

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    address public immutable factory;

    address public immutable token0;

    address public immutable token1;

    uint256 public immutable upperBound;

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

    constructor() ERC20("Numoen LP", "NLP", 18) {
        factory = msg.sender;
        (token0, token1, upperBound) = Factory(msg.sender).parameters();
    }

    /*//////////////////////////////////////////////////////////////
                              PAIR LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint(
        uint256 amount0,
        uint256 amount1,
        address to,
        bytes calldata data
    ) external lock returns (uint256 liquidity) {
        (uint256 balance0Before, uint256 balance1Before) = balances();

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = (amount0 + amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min((amount0 * _totalSupply) / balance0Before, (amount1 * _totalSupply) / balance1Before);
        }

        if (liquidity == 0) revert InsufficientOutputError();
        _mint(to, liquidity); // optimistic mint

        IPairMintCallback(msg.sender).PairMintCallback(amount0, amount1, data);

        (uint256 balance0After, uint256 balance1After) = balances();

        if (balance0After - balance0Before < amount0) revert InsufficientInputError();
        if (balance1After - balance1Before < amount1) revert InsufficientInputError();

        emit Mint(msg.sender, amount0, amount1, liquidity, to);
    }

    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint256 balance0, uint256 balance1) = balances();

        uint256 liquidity = balanceOf[address(this)];
        uint256 _totalSupply = totalSupply;
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;

        // TODO: can we make this &&
        if (amount0 == 0 || amount1 == 0) revert InsufficientBurnError();

        _burn(address(this), liquidity); // burn from self for composability

        SafeTransferLib.safeTransfer(ERC20(token0), to, amount0);
        SafeTransferLib.safeTransfer(ERC20(token1), to, amount1);

        emit Burn(msg.sender, amount0, amount1, liquidity, to);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external lock returns (uint256 amount0In, uint256 amount1In) {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputError();

        (uint256 balance0Before, uint256 balance1Before) = balances();
        uint256 invariantBefore = balance0Before + balance1Before;

        if (amount0Out > 0) SafeTransferLib.safeTransfer(ERC20(token0), to, amount0Out);
        if (amount1Out > 0) SafeTransferLib.safeTransfer(ERC20(token1), to, amount1Out);

        ISwapCallback(msg.sender).SwapCallback(amount0Out, amount1Out, data);

        {
            (uint256 balance0After, uint256 balance1After) = balances();
            amount0In = balance0After + amount0Out - balance0Before;
            amount1In = balance1After + amount1Out - balance1Before;

            uint256 invariantAfter = balance0After + balance1After;

            if (invariantBefore > invariantAfter) revert InvariantError();
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
}

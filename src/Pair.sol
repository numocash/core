// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "./Factory.sol";
import { Lendgine } from "./Lendgine.sol";

import { TransferHelper } from "./libraries/TransferHelper.sol";

/// @notice A gas efficient and opinionated capped power invariant pair
/// @author Kyle Scott (https://github.com/numoen/core/blob/master/src/Pair.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol)
/// Primitive (https://github.com/primitivefinance/rmm-core/blob/main/contracts/PrimitiveEngine.sol),
/// and Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
contract Pair {
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

    /// @notice The contract that deployed the pair
    address public immutable factory;

    /// @notice The associated lending market for these liquidity shares
    address public immutable lendgine;

    /// @notice The base token of the pair
    address public immutable base;

    /// @notice The speculative token of the pair
    address public immutable speculative;

    /// @notice The upper price limit of the CFMM, the exchange rate offered by this pool will never exceed this value
    uint256 public immutable upperBound;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The total supply of CFMM shares
    uint256 public totalSupply;

    /// @notice The amount of tokens that are currently unowned by the `lendgine`
    /// @dev This acts as the communication channel between the pair and lendgine, instead of implementing a full ERC20
    /// balance schematic, this buffer is used to express tokens that are about to be burned, deposited, or withdrawn
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

    /// @notice Verifies that the given amounts satisfy the trading invariant
    /// @param r0 The amount of `base` tokens
    /// @param r1 The amount of `speculative` tokens
    /// @param shares The amount of liquidity shares
    /// @return valid Whether or not the invariant passed
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

    /// @notice Create a liquidity providing position
    /// @dev This assumes the amount of each token that is to be deposited has already been
    /// sent to this contract prior to invoking this function
    /// @param liquidity The amount of liquidity shares requested
    function mint(uint256 liquidity) external lock {
        if (liquidity == 0) revert InsufficientOutputError();

        (uint256 balance0, uint256 balance1) = balances();
        if (!verifyInvariant(balance0, balance1, liquidity + totalSupply)) revert InvariantError();
        _mint(liquidity);

        emit Mint(msg.sender, liquidity);
    }

    /// @notice Destroy a liquidity providing position and receive the underlying balances
    /// @param to The address to receive the underlying balances
    /// @param amount0 The amount of `base` tokens to receive
    /// @param amount1 The amount of `speculative` tokens to receive
    /// @param liquidity The amount of liquidity shares to burn
    function burn(
        address to,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    ) external lock {
        if (!verifyInvariant(amount0, amount1, liquidity)) revert InvariantError();

        if (amount0 == 0 && amount1 == 0) revert InsufficientOutputError();
        _burn(liquidity);

        TransferHelper.safeTransfer(base, to, amount0);
        TransferHelper.safeTransfer(speculative, to, amount1);

        emit Burn(msg.sender, amount0, amount1, liquidity, to);
    }

    /// @notice Exchange between the `base` and `speculative` tokens, either accepts or rejects the proposed trade
    /// @dev The tokens that are to be sent to be sent in for the swap are required
    /// this contract before the invocation of this function
    /// @param to The address to receive the output of the trade
    /// @param amount0Out The amount of `base` tokens requested out of the trade
    /// @param amount1Out The amount of `speculative` tokens requested out of the trade
    function swap(
        address to,
        uint256 amount0Out,
        uint256 amount1Out
    ) external lock {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputError();

        if (amount0Out > 0) TransferHelper.safeTransfer(base, to, amount0Out);
        if (amount1Out > 0) TransferHelper.safeTransfer(speculative, to, amount1Out);

        (uint256 balance0, uint256 balance1) = balances();
        if (!verifyInvariant(balance0, balance1, totalSupply)) revert InvariantError();

        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the `base` and `speculative` balances of the pool
    /// @dev Not to be relied upon anywhere else because of a potential readonly reentracy
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

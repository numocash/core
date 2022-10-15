// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

/// @notice Library for handling Lendgine ticks
/// @author Kyle Scott (https://github.com/Numoen/core/blob/master/src/libraries/Tick.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/Tick.sol)
/// and Muffin (https://github.com/muffinfi/muffin/blob/master/contracts/libraries/Ticks.sol)
library Tick {
    /**
     * @param liquidity The amount of liquidity a tick owns
     * @param rewardPerINPaid The reward per unit of liquidity * tick as of the last update to liquidity or tokensOwedPerLiquidity
     * @param tokensOwedPerLiqudity The fees owed per unit of liquidity in `speculative` tokens
     * @param prev The index of the next tick containing liquidity below this tick
     * @param next The index of the next tick containing liquidity above this tick
     */
    struct Info {
        uint256 liquidity;
        uint256 rewardPerINPaid;
        uint256 tokensOwedPerLiquidity;
        uint16 prev;
        uint16 next;
    }
}

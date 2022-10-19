// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { LiquidityMath } from "./LiquidityMath.sol";

/// @notice Library for handling Lendgine liquidity positions
/// @author Kyle Scott (https://github.com/Numoen/core/blob/master/src/libraries/Position.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/Position.sol)
library Position {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NoLiquidityError();

    /*//////////////////////////////////////////////////////////////
                            POSITION STRUCT
    //////////////////////////////////////////////////////////////*/

    /**
     * @param liquidity The amount of liquidity a position owns
     * @param rewardPerLiquidityPaid The reward per unit of liquidity as of the last update to liquidity or tokensOwed
     * @param tokensOwed The fees owed to the position owner in `speculative` tokens
     */
    struct Info {
        uint256 liquidity;
        uint256 rewardPerLiquidityPaid;
        uint256 tokensOwed;
    }

    /*//////////////////////////////////////////////////////////////
                              POSITION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Add or remove liquidity from a position
    function update(
        mapping(address => Position.Info) storage self,
        address owner,
        int256 liquidityDelta
    ) internal {
        Position.Info storage info = self[owner];

        if (liquidityDelta == 0) revert NoLiquidityError();

        info.liquidity = LiquidityMath.addDelta(info.liquidity, liquidityDelta);
    }

    /*//////////////////////////////////////////////////////////////
                           POSITION VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice Return a position identified by its owner and tick
    function get(mapping(address => Info) storage self, address owner)
        internal
        view
        returns (Position.Info storage position)
    {
        position = self[owner];
    }
}

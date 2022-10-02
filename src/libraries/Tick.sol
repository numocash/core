// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { LiquidityMath } from "./LiquidityMath.sol";

library Tick {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NoLiquidityError();

    struct Info {
        uint256 liquidity;
        uint256 rewardPerINPaid;
        uint256 tokensOwedPerLiquidity;
    }

    function update(
        mapping(uint24 => Tick.Info) storage self,
        uint24 tick,
        int256 liquidityDelta
    ) internal {
        Tick.Info storage info = self[tick];

        if (liquidityDelta == 0) revert NoLiquidityError();

        info.liquidity = LiquidityMath.addDelta(info.liquidity, liquidityDelta);
    }
}

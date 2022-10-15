// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

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
        mapping(bytes32 => Position.Info) storage self,
        bytes32 id,
        int256 liquidityDelta
    ) internal {
        Position.Info storage info = self[id];

        if (liquidityDelta == 0) revert NoLiquidityError();

        info.liquidity = LiquidityMath.addDelta(info.liquidity, liquidityDelta);
    }

    /*//////////////////////////////////////////////////////////////
                           POSITION VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice Return a position identified by its owner and tick
    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        uint16 tick
    ) internal view returns (Position.Info storage position) {
        position = self[getID(owner, tick)];
    }

    /// @notice Computer the unique identifier for a position based on the owner and tick
    function getID(address owner, uint16 tick) internal pure returns (bytes32 id) {
        id = keccak256(abi.encode(owner, tick));
    }
}

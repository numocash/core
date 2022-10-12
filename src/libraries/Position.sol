// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { LiquidityMath } from "./LiquidityMath.sol";

/// @notice Library for handling Lendgine Maker positions
/// @author Kyle Scott (https://github.com/kyscott18/kyleswap2.5/blob/main/src/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
library Position {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NoLiquidityError();

    /*//////////////////////////////////////////////////////////////
                            POSITION STRUCT
    //////////////////////////////////////////////////////////////*/

    struct Info {
        uint256 liquidity;
        uint256 rewardPerLiquidityPaid;
        uint256 tokensOwed;
    }

    /*//////////////////////////////////////////////////////////////
                              POSITION LOGIC
    //////////////////////////////////////////////////////////////*/

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

    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        uint24 tick
    ) internal view returns (Position.Info storage position) {
        position = self[getID(owner, tick)];
    }

    function getID(address owner, uint24 tick) internal pure returns (bytes32 id) {
        id = keccak256(abi.encode(owner, tick));
    }
}

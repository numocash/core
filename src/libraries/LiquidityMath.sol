// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @notice Math library for liquidity
/// @author Kyle Scott (https://github.com/kyscott18/kyleswap2.5/blob/main/src/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
library LiquidityMath {
    /// @notice Add a signed liquidity delta to liquidity and revert if it overflows or underflows
    /// @param x The liquidity before change
    /// @param y The delta by which liquidity should be changed
    /// @return z The liquidity delta
    function addDelta(uint256 x, int256 y) internal pure returns (uint256 z) {
        if (y < 0) {
            require((z = x - uint256(-y)) < x, "LS");
        } else {
            require((z = x + uint256(y)) >= x, "LA");
        }
    }
}

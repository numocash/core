// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

/// @notice A library for performing various math operations
/// @author Kyle Scott (https://github.com/kyscott18/kyleswap2.5/blob/main/src/libraries/Math.sol)
/// @author Modified from Solidly
library Math {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { Lendgine } from "../Lendgine.sol";

/// @notice from uniswap
library LendgineAddress {
    /// @notice The identifying key of the pool
    struct LendgineKey {
        address token0;
        address token1;
        uint256 upperBound;
    }

    function getLendgineKey(
        address token0,
        address token1,
        uint256 upperBound
    ) internal pure returns (LendgineKey memory) {
        return LendgineKey({ token0: token0, token1: token1, upperBound: upperBound });
    }

    function computeAddress(
        address factory,
        address speculativeToken,
        address pair,
        uint256 upperBound
    ) internal pure returns (address) {
        address out = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encode(speculativeToken, pair, upperBound)),
                            keccak256(type(Lendgine).creationCode)
                        )
                    )
                )
            )
        );
        return out;
    }
}

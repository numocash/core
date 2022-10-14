// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

library Tick {
    struct Info {
        uint256 liquidity;
        uint256 rewardPerINPaid;
        uint256 tokensOwedPerLiquidity;
        uint16 prev;
        uint16 next;
    }
}

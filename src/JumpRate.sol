// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

abstract contract JumpRate {
    uint256 public constant baseRate = 1 ether;
    uint256 public constant kink = 1 ether;
    uint256 public constant jumpRate = 1 ether;

    function getBorrowRate(uint256 borrowedLiquidity, uint256 totalLiquidity) internal pure returns (uint256 rate) {
        borrowedLiquidity;
        totalLiquidity;
        rate = 0;
    }

    function getSupplyRate(uint256 borrowedLiquidity, uint256 totalLiquidity) internal pure returns (uint256 rate) {
        borrowedLiquidity;
        totalLiquidity;
        rate = 0;
    }
}

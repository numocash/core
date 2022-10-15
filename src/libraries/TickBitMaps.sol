// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

/// @notice Packed tick initialized state library
/// @author Kyle Scott (https://github.com/Numoen/core/blob/master/src/libraries/TickBitMaps.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickBitmap.sol)
// and Muffin (https://github.com/muffinfi/muffin/blob/master/contracts/libraries/TickMaps.sol)
library TickBitMaps {
    struct TickBitMap {
        uint256 blockMap; // A bit map showing which blocks contain active ticks
        uint16 firstTick; // The index of the first active tick, zero if there are none
        mapping(uint256 => uint256) blocks; // Stores which ticks are initialized
    }

    /// @notice compute the indices of the block and bit that the tick uses
    function position(uint16 tick) private pure returns (uint256 blockIdx, uint256 bitIdx) {
        unchecked {
            blockIdx = tick >> 8;
            bitIdx = tick % 256;
            assert(blockIdx < 256);
        }
    }

    /// @notice turn on or off a tick in the map
    /// @param tick The tick to toggle
    /// @param on Boolean on whether to turn the tick on or off
    function flipTick(
        TickBitMap storage self,
        uint16 tick,
        bool on
    ) internal {
        (uint256 blockIdx, uint256 bitIdx) = position(tick);

        if (on) {
            self.blocks[blockIdx] |= 1 << bitIdx;
            self.blockMap |= 1 << blockIdx;
        } else {
            self.blocks[blockIdx] &= ~(1 << bitIdx);

            if (self.blocks[blockIdx] == 0) {
                self.blockMap &= ~(1 << blockIdx);
            }
        }
    }

    /// @notice Find the next tick below tick that has liquidity
    /// @dev Should only be called for ticks with known ticks below
    /// @param tick The tick to search below
    /// @return tickBelow The closest tick below that contains liquidity
    function below(TickBitMap storage self, uint16 tick) internal view returns (uint16 tickBelow) {
        unchecked {
            (uint256 blockIdx, uint256 bitIdx) = position(tick);

            uint256 bit = self.blocks[blockIdx] & ((1 << bitIdx) - 1);

            // if there are no utilized ticks in the current block
            if (bit == 0) {
                uint256 _block = self.blockMap & ((1 << blockIdx) - 1);
                assert(_block != 0);
                blockIdx = _msb(_block);
                bit = self.blocks[blockIdx];
            }

            tickBelow = uint16((blockIdx << 8) | _msb(bit));
        }
    }

    /// @notice Returns the index of the most significant bit of the number, where the least significant bit is at
    /// index 0 and the most significant bit is at index 255
    /// @dev The function satisfies the property: x >= 2**mostSignificantBit(x) and x < 2**(mostSignificantBit(x)+1)
    /// @param x the value for which to compute the most significant bit, must be greater than 0
    /// @return r the index of the most significant bit
    function _msb(uint256 x) internal pure returns (uint8 r) {
        unchecked {
            assert(x > 0);
            if (x >= 0x100000000000000000000000000000000) {
                x >>= 128;
                r += 128;
            }
            if (x >= 0x10000000000000000) {
                x >>= 64;
                r += 64;
            }
            if (x >= 0x100000000) {
                x >>= 32;
                r += 32;
            }
            if (x >= 0x10000) {
                x >>= 16;
                r += 16;
            }
            if (x >= 0x100) {
                x >>= 8;
                r += 8;
            }
            if (x >= 0x10) {
                x >>= 4;
                r += 4;
            }
            if (x >= 0x4) {
                x >>= 2;
                r += 2;
            }
            if (x >= 0x2) r += 1;
        }
    }
}

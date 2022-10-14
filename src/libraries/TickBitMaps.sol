// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/console2.sol";

library TickBitMaps {
    struct TickBitMap {
        uint256 blockMap;
        uint16 firstTick;
        mapping(uint256 => uint256) blocks;
    }

    function position(uint16 tick) private pure returns (uint256 blockIdx, uint256 bitIdx) {
        unchecked {
            blockIdx = tick >> 8;
            bitIdx = tick % 256;
            assert(blockIdx < 256);
        }
    }

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

    /// @dev this is only called if there is a tick below
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

    /// @notice Returns the index of the most significant bit of the number, where the least significant bit is at index 0
    /// and the most significant bit is at index 255
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

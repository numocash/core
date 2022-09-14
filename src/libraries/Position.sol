// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { LiquidityMath } from "./LiquidityMath.sol";

/// @notice Library for handling Lendgine Maker positions
/// @author Kyle Scott (https://github.com/kyscott18/kyleswap2.5/blob/main/src/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @dev Implements a doubley linked list
library Position {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error NoLiquidityError();

    /*//////////////////////////////////////////////////////////////
                            POSITION STRUCT
    //////////////////////////////////////////////////////////////*/

    struct Info {
        bytes32 next;
        bytes32 previous;
        uint256 liquidity;
        uint256 tokensOwed;
        uint256 rewardPerTokenPaid;
        bool utilized;
    }

    /*//////////////////////////////////////////////////////////////
                              POSITION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev -liquidityDelta should not equal self.liquidity
    function update(Info storage self, int256 liquidityDelta) internal {
        Info memory _self = self;

        if (liquidityDelta == 0) revert NoLiquidityError();

        self.liquidity = LiquidityMath.addDelta(_self.liquidity, liquidityDelta);
    }

    /// @dev assumes current is not already in use
    /// @dev assigns a zero value to current liquidity
    // TODO: pass in a non-empty Info to assign
    function append(
        mapping(bytes32 => Info) storage self,
        bytes32 current,
        bytes32 end,
        Info memory infoData
    ) internal {
        Info memory newInfo;
        if (end == bytes32(0)) {
            newInfo = Info({
                liquidity: infoData.liquidity,
                next: bytes32(0),
                previous: 0,
                utilized: false,
                tokensOwed: infoData.tokensOwed,
                rewardPerTokenPaid: infoData.rewardPerTokenPaid
            });
            self[current] = newInfo;
            return;
        }

        Info memory _end = self[end];
        _end.next = current;
        self[end] = _end;

        newInfo = Info({
            liquidity: infoData.liquidity,
            next: bytes32(0),
            previous: end,
            utilized: false,
            tokensOwed: infoData.tokensOwed,
            rewardPerTokenPaid: infoData.rewardPerTokenPaid
        });
        self[current] = newInfo;
    }

    function remove(mapping(bytes32 => Info) storage self, bytes32 current) internal returns (uint256, bytes32) {
        Info memory _current = self[current];

        if (_current.previous != bytes32(0)) {
            self[_current.previous].next = _current.next;
        }
        if (_current.next != bytes32(0)) {
            self[_current.next].previous = _current.previous;
        }

        uint256 tokensOwed = _current.tokensOwed;

        // This resets to the default values
        delete self[current];

        return (tokensOwed, _current.previous);
    }

    /*//////////////////////////////////////////////////////////////
                           POSITION VIEW
    //////////////////////////////////////////////////////////////*/

    function get(mapping(bytes32 => Info) storage self, address owner)
        internal
        view
        returns (Position.Info storage position)
    {
        position = self[getId(owner)];
    }

    function getId(address owner) internal pure returns (bytes32 Id) {
        Id = keccak256(abi.encodePacked(owner));
    }
}

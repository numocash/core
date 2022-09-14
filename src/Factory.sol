// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Lendgine } from "./Lendgine.sol";

import "forge-std/console2.sol";

/// @notice Manages the recording and create of lending engines
/// @author Kyle Scott (https://github.com/kyscott18/kyleswap2.5/blob/main/src/Factory.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Factory.sol)
/// and Primitive (https://github.com/primitivefinance/rmm-core/blob/main/contracts/PrimitiveFactory.sol)
contract Factory {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LendgineCreated(
        address indexed speculativeToken,
        address indexed lpToken,
        uint256 indexed upperBound,
        address lendgine
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SameTokenError();

    error ZeroAddressError();

    error DeployedError();

    /*//////////////////////////////////////////////////////////////
                            FACTORY STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(address => mapping(uint256 => address))) public getLendgine;

    /*//////////////////////////////////////////////////////////////
                        TEMPORARY DEPLOY STORAGE
    //////////////////////////////////////////////////////////////*/

    struct Parameters {
        address speculativeToken;
        address lpToken;
        uint256 upperBound;
    }

    Parameters public parameters;

    /*//////////////////////////////////////////////////////////////
                              FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    function createLendgine(
        address speculativeToken,
        address lpToken,
        uint256 upperBound
    ) external returns (address lendgine) {
        if (speculativeToken == lpToken) revert SameTokenError();

        if (speculativeToken == address(0) || lpToken == address(0)) revert ZeroAddressError();
        if (getLendgine[speculativeToken][lpToken][upperBound] != address(0)) revert DeployedError();

        parameters = Parameters({ speculativeToken: speculativeToken, lpToken: lpToken, upperBound: upperBound });
        lendgine = address(new Lendgine{ salt: keccak256(abi.encode(speculativeToken, lpToken, upperBound)) }());
        delete parameters;

        getLendgine[speculativeToken][lpToken][upperBound] = lendgine;

        emit LendgineCreated(speculativeToken, lpToken, upperBound, lendgine);
    }
}

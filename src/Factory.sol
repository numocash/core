// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Lendgine } from "./Lendgine.sol";
import { Pair } from "./Pair.sol";

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
        address indexed baseToken,
        uint256 indexed upperBound,
        address lendgine,
        address pair
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
        address baseToken;
        uint256 upperBound;
    }

    Parameters public parameters;

    address public pair;

    /*//////////////////////////////////////////////////////////////
                              FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    function createLendgine(
        address speculativeToken,
        address baseToken,
        uint256 upperBound
    ) external returns (address _lendgine, address _pair) {
        if (speculativeToken == baseToken) revert SameTokenError();

        if (speculativeToken == address(0) || baseToken == address(0)) revert ZeroAddressError();
        if (getLendgine[speculativeToken][baseToken][upperBound] != address(0)) revert DeployedError();

        parameters = Parameters({ speculativeToken: speculativeToken, baseToken: baseToken, upperBound: upperBound });

        _pair = address(new Pair{ salt: keccak256(abi.encode(speculativeToken, baseToken, upperBound)) }());
        pair = _pair;
        _lendgine = address(new Lendgine{ salt: keccak256(abi.encode(speculativeToken, baseToken, upperBound)) }());

        delete parameters;
        delete pair;

        getLendgine[speculativeToken][baseToken][upperBound] = _lendgine;

        emit LendgineCreated(speculativeToken, baseToken, upperBound, _lendgine, _pair);
    }
}

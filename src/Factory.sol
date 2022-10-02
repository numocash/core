// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Lendgine } from "./Lendgine.sol";
import { Pair } from "./Pair.sol";

/// @notice Manages the recording and create of lending engines
/// @author Kyle Scott (https://github.com/numoen/core/blob/master/src/Factory.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Factory.sol)
/// and Primitive (https://github.com/primitivefinance/rmm-core/blob/main/contracts/PrimitiveFactory.sol)
contract Factory {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LendgineCreated(
        address indexed baseToken,
        address indexed speculativeToken,
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
        address baseToken;
        address speculativeToken;
        uint256 upperBound;
    }

    Parameters public parameters;

    /*//////////////////////////////////////////////////////////////
                              FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    function createLendgine(
        address baseToken,
        address speculativeToken,
        uint256 upperBound
    ) external returns (address _lendgine) {
        if (speculativeToken == baseToken) revert SameTokenError();
        if (speculativeToken == address(0) || baseToken == address(0)) revert ZeroAddressError();
        if (getLendgine[baseToken][speculativeToken][upperBound] != address(0)) revert DeployedError();

        parameters = Parameters({ baseToken: baseToken, speculativeToken: speculativeToken, upperBound: upperBound });
        _lendgine = address(new Lendgine{ salt: keccak256(abi.encode(baseToken, speculativeToken, upperBound)) }());

        delete parameters;

        getLendgine[baseToken][speculativeToken][upperBound] = _lendgine;

        emit LendgineCreated(baseToken, speculativeToken, upperBound, _lendgine);
    }
}

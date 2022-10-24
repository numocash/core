// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import { Lendgine } from "./Lendgine.sol";
import { Pair } from "./Pair.sol";

import { IFactory } from "./interfaces/IFactory.sol";

contract Factory is IFactory {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event LendgineCreated(
        address indexed base,
        address indexed speculative,
        uint256 baseScaleFactor,
        uint256 speculativeScaleFactor,
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

    /// @inheritdoc IFactory
    mapping(address => mapping(address => mapping(uint256 => mapping(uint256 => mapping(uint256 => address)))))
        public
        override getLendgine;

    /*//////////////////////////////////////////////////////////////
                        TEMPORARY DEPLOY STORAGE
    //////////////////////////////////////////////////////////////*/

    struct Parameters {
        address base;
        address speculative;
        uint256 baseScaleFactor;
        uint256 speculativeScaleFactor;
        uint256 upperBound;
    }

    /// @inheritdoc IFactory
    Parameters public override parameters;

    /*//////////////////////////////////////////////////////////////
                              FACTORY LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFactory
    function createLendgine(
        address base,
        address speculative,
        uint256 baseScaleFactor,
        uint256 speculativeScaleFactor,
        uint256 upperBound
    ) external override returns (address lendgine) {
        if (speculative == base) revert SameTokenError();
        if (speculative == address(0) || base == address(0)) revert ZeroAddressError();
        if (getLendgine[base][speculative][baseScaleFactor][speculativeScaleFactor][upperBound] != address(0))
            revert DeployedError();

        parameters = Parameters({
            base: base,
            speculative: speculative,
            baseScaleFactor: baseScaleFactor,
            speculativeScaleFactor: speculativeScaleFactor,
            upperBound: upperBound
        });
        lendgine = address(
            new Lendgine{
                salt: keccak256(abi.encode(base, speculative, baseScaleFactor, speculativeScaleFactor, upperBound))
            }()
        );

        delete parameters;

        getLendgine[base][speculative][baseScaleFactor][speculativeScaleFactor][upperBound] = lendgine;

        emit LendgineCreated(base, speculative, baseScaleFactor, speculativeScaleFactor, upperBound, lendgine);
    }
}

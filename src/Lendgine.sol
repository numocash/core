// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "./Factory.sol";
import { Pair } from "./Pair.sol";

import { IMintCallback } from "./interfaces/IMintCallback.sol";

import { Position } from "./libraries/Position.sol";
import { Tick } from "./libraries/Tick.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

/// @notice A general purpose funding rate engine
/// @author Kyle Scott (https://github.com/numoen/core/blob/master/src/Lendgine.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol)
/// and Primitive (https://github.com/primitivefinance/rmm-core/blob/main/contracts/PrimitiveEngine.sol)
contract Lendgine is ERC20 {
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    using Tick for mapping(uint24 => Tick.Info);
    using Tick for Tick.Info;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address indexed sender, uint256 amountS, uint256 shares, uint256 liquidity, address indexed to);

    event Burn(address indexed sender, uint256 amountS, uint256 shares, uint256 liquidity, address indexed to);

    event Deposit(address indexed sender, address indexed to, uint256 amountLP, uint24 tick);

    event Withdraw(address indexed to, uint256 amountLP, uint24 tick);

    event AccrueInterest();

    event AccrueMakerInterest();

    event Collect(address indexed owner, address indexed to, uint256 amountBase);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ReentrancyError();

    error BalanceReturnError();

    error InvalidTick();

    error InsufficientInputError();

    error InsufficientOutputError();

    error CompleteUtilizationError();

    error InsufficientPositionError();

    error UnutilizedAccrueError();

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable factory;

    address public immutable pair;

    /*//////////////////////////////////////////////////////////////
                          LENDGINE STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(bytes32 => Position.Info) public positions;

    mapping(uint24 => Tick.Info) public ticks;

    // tick 0 corresponds to empty
    uint24 public currentTick;

    uint256 public currentLiquidity;

    uint256 public interestNumerator;

    uint256 public totalLiquidityBorrowed;

    uint256 public rewardPerINStored;

    uint40 public lastUpdate;

    /*//////////////////////////////////////////////////////////////
                           REENTRANCY LOGIC
    //////////////////////////////////////////////////////////////*/

    uint256 private locked = 1;

    modifier lock() virtual {
        if (locked != 1) revert ReentrancyError();

        locked = 2;

        _;

        locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20("Numoen Lendgine", "NLDG", 18) {
        factory = msg.sender;

        pair = address(new Pair{ salt: keccak256(abi.encode(address(this))) }(msg.sender));
    }

    /*//////////////////////////////////////////////////////////////
                            MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint(
        address to,
        uint256 amountS,
        bytes calldata data
    ) external lock returns (uint256) {
        _accrueInterest();

        if (currentTick == 0) revert CompleteUtilizationError();

        uint256 liquidity = convertAssetToLiquidity(amountS);
        uint256 shares = convertLiquidityToShare(liquidity);

        if (shares == 0) revert InsufficientOutputError();

        uint256 interestNumeratorDelta = increaseCurrentLiquidity(liquidity);
        interestNumerator += interestNumeratorDelta;
        totalLiquidityBorrowed += liquidity;

        _mint(to, shares); // optimistically mint
        Pair(pair).addBuffer(liquidity);

        uint256 balanceBefore = balanceSpeculative();
        IMintCallback(msg.sender).MintCallback(amountS, data);
        uint256 balanceAfter = balanceSpeculative();
        if (balanceAfter < balanceBefore + amountS) revert InsufficientInputError();

        emit Mint(msg.sender, amountS, shares, liquidity, to);
        return shares;
    }

    function burn(address to) external lock {
        _accrueInterest();

        uint256 shares = balanceOf[address(this)];
        uint256 liquidity = convertShareToLiquidity(shares);
        uint256 amountS = convertLiquidityToAsset(liquidity);

        if (liquidity == 0) revert InsufficientOutputError();

        uint256 interestNumeratorDelta = decreaseCurrentLiquidity(liquidity);
        interestNumerator -= interestNumeratorDelta;
        totalLiquidityBorrowed -= liquidity;

        _burn(address(this), shares);
        Pair(pair).removeBuffer(liquidity);
        SafeTransferLib.safeTransfer(ERC20(Pair(pair).speculative()), to, amountS);

        emit Burn(msg.sender, amountS, shares, liquidity, to);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(address recipient, uint24 tick) external lock {
        uint256 amountLP = Pair(pair).buffer();

        Position.Info storage position = positions.get(recipient, tick);
        bytes32 id = Position.getId(recipient, tick);

        if (amountLP == 0) revert InsufficientOutputError();
        if (tick == 0) revert InvalidTick();

        // trigger accruals if current position is utilized
        {
            bool utilized = (currentTick == tick && currentLiquidity > 0) || (tick < currentTick);

            if (utilized) {
                _accrueInterest();
                if (tick != currentTick) _accrueTickInterest(tick);
                _accrueMakerInterest(id, tick);
            }
        }

        ticks.update(tick, int256(amountLP));
        position.update(int256(amountLP));

        // remove liquidity if we bumped someone out
        if (tick < currentTick) {
            // TODO: update interestNumerator
            decreaseCurrentLiquidity(amountLP);
        }

        if (currentTick == 0) {
            currentTick = tick;
        }

        Pair(pair).removeBuffer(amountLP);

        emit Deposit(msg.sender, recipient, amountLP, tick);
    }

    function withdraw(uint24 tick, uint256 amountLP) external lock {
        if (tick == 0) revert InvalidTick();

        Position.Info storage position = positions.get(msg.sender, tick);
        bytes32 id = Position.getId(msg.sender, tick);

        bool utilized = (currentTick == tick && currentLiquidity > 0) || (tick < currentTick);

        if (utilized) {
            _accrueInterest();
            if (tick != currentTick) _accrueTickInterest(tick);
            _accrueMakerInterest(id, tick);
        }

        if (amountLP == 0) revert InsufficientOutputError();

        uint256 utilizedLP;

        if (tick == currentTick) {
            if (currentLiquidity > position.liquidity - amountLP) {
                utilizedLP = currentLiquidity - (position.liquidity - amountLP);
            }

            if (amountLP == position.liquidity) {
                // if fully removing position
                // TODO: write to stack instead
                currentLiquidity = 0;
            }
        } else if (tick < currentTick) {
            utilizedLP = amountLP;
        }

        if (amountLP > position.liquidity) revert InsufficientPositionError();

        // Remove position from the data structure
        // if tick needs to advance to the next tick
        if (currentTick == tick && currentLiquidity > position.liquidity - amountLP) {
            currentLiquidity = position.liquidity - amountLP;
        }

        ticks.update(tick, -int256(amountLP));
        position.update(-int256(amountLP));

        // Replace if we removed utilized liquidity
        if (utilizedLP > 0) {
            // TODO: update interestNumerator
            increaseCurrentLiquidity(utilizedLP);
        }

        Pair(pair).addBuffer(amountLP);

        emit Withdraw(msg.sender, amountLP, tick);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEREST LOGIC
    //////////////////////////////////////////////////////////////*/

    function accrueInterest() external lock {
        _accrueInterest();
    }

    function accrueTickInterest(uint24 tick) external lock {
        if (tick == 0) revert InvalidTick();
        _accrueInterest();
        if (tick != currentTick) _accrueTickInterest(tick);
    }

    function accrueMakerInterest(bytes32 id, uint24 tick) external lock {
        if (tick == 0) revert InvalidTick();

        _accrueInterest();
        if (tick != currentTick) _accrueTickInterest(tick);
        _accrueMakerInterest(id, tick);
    }

    function collectMaker(address recipient, uint24 tick) external lock returns (uint256 collectedTokens) {
        if (tick == 0) revert InvalidTick();

        Position.Info storage position = positions.get(msg.sender, tick);

        collectedTokens = position.tokensOwed;

        if (collectedTokens == 0) revert InsufficientOutputError();

        position.tokensOwed = 0;

        SafeTransferLib.safeTransfer(ERC20(Pair(pair).speculative()), recipient, collectedTokens);

        emit Collect(msg.sender, recipient, collectedTokens);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function convertLiquidityToShare(uint256 liquidity) public view returns (uint256) {
        uint256 _totalLiquidityBorrowed = totalLiquidityBorrowed;
        return _totalLiquidityBorrowed == 0 ? liquidity : (liquidity * totalSupply) / _totalLiquidityBorrowed;
    }

    function convertShareToLiquidity(uint256 shares) public view returns (uint256) {
        return (totalLiquidityBorrowed * shares) / totalSupply;
    }

    function convertAssetToLiquidity(uint256 assets) public view returns (uint256) {
        return (assets * 10**18) / (2 * Pair(pair).upperBound());
    }

    function convertLiquidityToAsset(uint256 liquidity) public view returns (uint256) {
        return (2 * liquidity * Pair(pair).upperBound()) / 10**18;
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    function balanceSpeculative() public view returns (uint256) {
        bool success;
        bytes memory data;

        (success, data) = Pair(pair).speculative().staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("balanceOf(address)"))), address(this))
        );
        if (!success || data.length < 32) revert BalanceReturnError();

        return abi.decode(data, (uint256));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Current position is assumed to be valid
    function increaseCurrentLiquidity(uint256 amountLP) private returns (uint256 interestNumeratorDelta) {
        uint24 _currentTick = currentTick;
        Tick.Info memory currentTickInfo = ticks[_currentTick];

        // amount of speculative in this tick available
        uint256 remainingCurrentLiquidity = currentTickInfo.liquidity - currentLiquidity;
        uint256 remainingLP = amountLP; // amount of pair lp tokens to be added

        while (true) {
            if (remainingCurrentLiquidity >= remainingLP) {
                break;
            } else {
                interestNumeratorDelta += _currentTick * remainingCurrentLiquidity;

                _currentTick = _currentTick + 1;
                currentLiquidity = 0;
                // TODO: error when max tick is reached
                currentTickInfo = ticks[_currentTick];

                remainingLP -= remainingCurrentLiquidity;
                remainingCurrentLiquidity = currentTickInfo.liquidity;
            }
        }

        interestNumeratorDelta += _currentTick * remainingLP;
        currentTick = _currentTick;
        currentLiquidity += remainingLP;
    }

    /// @dev assumed to never decrease past zero
    function decreaseCurrentLiquidity(uint256 amountLP) private returns (uint256 interestNumeratorDelta) {
        uint24 _currentTick = currentTick;
        Tick.Info memory currentTickInfo = ticks[_currentTick];

        uint256 remainingCurrentLiquidity = currentLiquidity;
        uint256 remainingLP = amountLP;

        while (true) {
            if (remainingCurrentLiquidity >= remainingLP) {
                break;
            } else {
                interestNumeratorDelta += _currentTick * remainingCurrentLiquidity;

                // should never underflow
                _currentTick = _currentTick - 1;
                currentTickInfo = ticks[_currentTick];

                remainingLP -= remainingCurrentLiquidity;
                remainingCurrentLiquidity = currentTickInfo.liquidity;
                _accrueTickInterest(_currentTick);
            }
        }

        interestNumeratorDelta += _currentTick * remainingLP;
        currentTick = _currentTick;
        currentLiquidity = remainingCurrentLiquidity - remainingLP;
    }

    function _accrueInterest() private {
        if (totalSupply == 0) {
            lastUpdate = uint40(block.timestamp);
            return;
        }

        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed == 0 || interestNumerator == 0) return;

        // calculate how much must be removed
        uint256 dilutionLP = (interestNumerator * timeElapsed) / (1 days * 10_000);
        uint256 dilutionSpeculative = convertLiquidityToAsset(dilutionLP);

        rewardPerINStored += (dilutionSpeculative * 1 ether) / interestNumerator;

        _accrueTickInterest(currentTick);

        uint256 interestNumeratorDelta = decreaseCurrentLiquidity(dilutionLP);
        totalLiquidityBorrowed -= dilutionLP;
        interestNumerator -= interestNumeratorDelta;

        // TODO: dilution > baseReserves;
        lastUpdate = uint40(block.timestamp);

        emit AccrueInterest();
    }

    function _accrueTickInterest(uint24 tick) private {
        if (tick > currentTick) revert UnutilizedAccrueError();

        Tick.Info storage tickInfo = ticks[tick];
        Tick.Info memory _tickInfo = tickInfo;

        uint256 tokensOwed = newTokensOwed(_tickInfo, tick);

        tickInfo.rewardPerINPaid = rewardPerINStored;
        if (tokensOwed > 0)
            tickInfo.tokensOwedPerLiquidity =
                _tickInfo.tokensOwedPerLiquidity +
                ((tokensOwed * 1 ether) / _tickInfo.liquidity);

        emit AccrueMakerInterest();
    }

    /// @dev assume global interest accrual is up to date
    function _accrueMakerInterest(bytes32 id, uint24 tick) private {
        // TODO: assert tick is matched with correct id
        Position.Info storage position = positions[id];
        Position.Info memory _position = position;

        Tick.Info storage tickInfo = ticks[tick];
        Tick.Info memory _tickInfo = tickInfo;

        uint256 tokensOwed = newTokensOwed(_position, _tickInfo);

        position.rewardPerLiquidityPaid = tickInfo.tokensOwedPerLiquidity;
        position.tokensOwed = _position.tokensOwed + tokensOwed;

        emit AccrueMakerInterest();
    }

    /// @dev Assumes reward per token stored is up to date
    function newTokensOwed(Tick.Info memory tickInfo, uint24 tick) private view returns (uint256) {
        if (tick > currentTick) return 0;
        uint256 liquidity = tickInfo.liquidity;
        if (currentTick == tick) {
            liquidity = currentLiquidity;
        }
        uint256 owed = (liquidity * tick * (rewardPerINStored - tickInfo.rewardPerINPaid)) / 1 ether;
        return owed;
    }

    /// @dev Assumes reward per token stored is up to date
    function newTokensOwed(Position.Info memory position, Tick.Info memory tickInfo) private pure returns (uint256) {
        uint256 liquidity = position.liquidity;

        uint256 owed = (liquidity * (tickInfo.tokensOwedPerLiquidity - position.rewardPerLiquidityPaid)) / (1 ether);
        return owed;
    }
}

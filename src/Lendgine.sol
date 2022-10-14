// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "./Factory.sol";
import { Pair } from "./Pair.sol";

import { IMintCallback } from "./interfaces/IMintCallback.sol";

import { Position } from "./libraries/Position.sol";
import { Tick } from "./libraries/Tick.sol";
import { TickBitMaps } from "./libraries/TickBitMaps.sol";
import { LiquidityMath } from "./libraries/LiquidityMath.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import "forge-std/console2.sol";

/// @notice A general purpose funding rate engine
/// @author Kyle Scott (https://github.com/numoen/core/blob/master/src/Lendgine.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v3-core/blob/main/contracts/UniswapV3Pool.sol)
/// and Primitive (https://github.com/primitivefinance/rmm-core/blob/main/contracts/PrimitiveEngine.sol)
contract Lendgine is ERC20 {
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Tick for mapping(uint16 => Tick.Info);
    using Tick for Tick.Info;
    using TickBitMaps for TickBitMaps.TickBitMap;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address indexed sender, uint256 amountS, uint256 shares, uint256 liquidity, address indexed to);

    event Burn(address indexed sender, uint256 amountS, uint256 shares, uint256 liquidity, address indexed to);

    event Deposit(address indexed sender, uint256 liquidity, uint16 tick, address indexed to);

    event Withdraw(address indexed sender, uint256 liquidity, uint16 tick);

    event AccrueInterest(uint256 timeElapsed, uint256 amountS, uint256 liquidity, uint256 rewardPerIN);

    event AccrueTickInterest(uint16 indexed tick, uint256 rewardPerIN, uint256 tokensOwed);

    event AccruePositionInterest(
        uint16 indexed tick,
        bytes32 indexed id,
        uint256 rewardPerLiquidity,
        uint256 tokensOwed
    );

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

    uint16 public constant MaxTick = 10_000;

    address public immutable factory;

    address public immutable pair;

    /*//////////////////////////////////////////////////////////////
                          LENDGINE STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(bytes32 => Position.Info) public positions;

    mapping(uint16 => Tick.Info) public ticks;

    TickBitMaps.TickBitMap public tickBitMap;

    uint256 public currentLiquidity;

    uint256 public interestNumerator;

    uint256 public totalLiquidityBorrowed;

    uint256 public rewardPerINStored;

    uint64 public lastUpdate;

    /// @dev tick 0 corresponds to an uninitialized state
    uint16 public currentTick;

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
        StateCache memory cache = loadCache();

        _accrueInterest(cache);

        if (cache.currentTick == 0) revert CompleteUtilizationError();

        uint256 liquidity = convertAssetToLiquidity(amountS);
        uint256 shares = convertLiquidityToShare(liquidity);

        if (shares == 0) revert InsufficientOutputError();

        increaseCurrentLiquidity(liquidity, cache);

        currentTick = cache.currentTick;
        currentLiquidity = cache.currentLiquidity;
        interestNumerator = cache.interestNumerator;
        totalLiquidityBorrowed = cache.totalLiquidityBorrowed + liquidity;

        _mint(to, shares); // optimistically mint
        Pair(pair).addBuffer(liquidity);

        uint256 balanceBefore = balanceSpeculative();
        IMintCallback(msg.sender).MintCallback(amountS, data);
        uint256 balanceAfter = balanceSpeculative();
        if (balanceAfter < balanceBefore + amountS) revert InsufficientInputError();

        emit Mint(msg.sender, amountS, shares, liquidity, to);
        return shares;
    }

    function burn(address to) external lock returns (uint256) {
        StateCache memory cache = loadCache();

        _accrueInterest(cache);

        uint256 shares = balanceOf[address(this)];
        uint256 liquidity = convertShareToLiquidity(shares);
        uint256 amountS = convertLiquidityToAsset(liquidity);

        if (liquidity == 0) revert InsufficientOutputError();

        decreaseCurrentLiquidity(liquidity, cache);

        interestNumerator = cache.interestNumerator;
        totalLiquidityBorrowed = cache.totalLiquidityBorrowed - liquidity;
        currentLiquidity = cache.currentLiquidity;
        currentTick = cache.currentTick;

        _burn(address(this), shares);
        Pair(pair).removeBuffer(liquidity);
        SafeTransferLib.safeTransfer(ERC20(Pair(pair).speculative()), to, amountS);

        emit Burn(msg.sender, amountS, shares, liquidity, to);
        return amountS;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(address to, uint16 tick) external lock {
        StateCache memory cache = loadCache();

        uint256 liquidity = Pair(pair).buffer();

        if (liquidity == 0) revert InsufficientOutputError();
        if (tick == 0 || tick > MaxTick) revert InvalidTick();

        bytes32 id = Position.getID(to, tick);

        bool utilized = (cache.currentTick == tick && cache.currentLiquidity > 0) || (tick < cache.currentTick);
        if (utilized) {
            _accrueInterest(cache);
            if (tick != cache.currentTick) _accrueTickInterest(tick);
            _accruePositionInterest(id, tick);
        }

        updateTick(tick, int256(liquidity));
        positions.update(id, int256(liquidity));

        if (tick < cache.currentTick) {
            cache.interestNumerator += liquidity * tick;

            decreaseCurrentLiquidity(liquidity, cache);

            interestNumerator = cache.interestNumerator;
            currentLiquidity = cache.currentLiquidity;
            currentTick = cache.currentTick;
        } else if (cache.currentTick == 0) {
            currentTick = tick;
        }

        Pair(pair).removeBuffer(liquidity);
        emit Deposit(msg.sender, liquidity, tick, to);
    }

    function withdraw(uint16 tick, uint256 liquidity) external lock {
        StateCache memory cache = loadCache();

        if (liquidity == 0) revert InsufficientOutputError();
        if (tick == 0) revert InvalidTick();

        bytes32 id = Position.getID(msg.sender, tick);
        Position.Info memory positionInfo = positions.get(msg.sender, tick);
        Tick.Info memory tickInfo = ticks[tick];

        if (liquidity > positionInfo.liquidity) revert InsufficientPositionError();

        if ((cache.currentTick == tick && cache.currentLiquidity > 0) || (tick < cache.currentTick)) {
            _accrueInterest(cache);
            if (tick != cache.currentTick) _accrueTickInterest(tick);
            _accruePositionInterest(id, tick);
        }

        uint256 utilizedLiquidity = 0;
        uint256 remainingLiquidity = tickInfo.liquidity - liquidity;
        if (tick < cache.currentTick) {
            utilizedLiquidity = liquidity;
        } else if (tick == cache.currentTick && cache.currentLiquidity > remainingLiquidity) {
            utilizedLiquidity = cache.currentLiquidity - remainingLiquidity;

            cache.currentTick = tickInfo.next;
            cache.currentLiquidity = 0;
        }

        // Remove position from the data structure
        updateTick(tick, -int256(liquidity));
        positions.update(id, -int256(liquidity));

        // Replace if we removed utilized liquidity
        if (utilizedLiquidity > 0) {
            cache.interestNumerator -= utilizedLiquidity * tick;

            increaseCurrentLiquidity(utilizedLiquidity, cache);

            currentTick = cache.currentTick;
            currentLiquidity = cache.currentLiquidity;
            interestNumerator = cache.interestNumerator;
        }

        Pair(pair).addBuffer(liquidity);
        emit Withdraw(msg.sender, liquidity, tick);
    }

    /*//////////////////////////////////////////////////////////////
                            INTEREST LOGIC
    //////////////////////////////////////////////////////////////*/

    function accrueInterest() external lock {
        StateCache memory cache = loadCache();
        _accrueInterest(cache);
    }

    function accrueTickInterest(uint16 tick) external lock {
        if (tick == 0) revert InvalidTick();
        StateCache memory cache = loadCache();

        _accrueInterest(cache);
        if (tick != currentTick) _accrueTickInterest(tick);
    }

    function accruePositionInterest(uint16 tick) external lock {
        if (tick == 0) revert InvalidTick();

        bytes32 id = Position.getID(msg.sender, tick);
        StateCache memory cache = loadCache();

        _accrueInterest(cache);
        if (tick != currentTick) _accrueTickInterest(tick);
        _accruePositionInterest(id, tick);
    }

    function collect(
        address to,
        uint16 tick,
        uint256 amountSRequested
    ) external lock returns (uint256 amountS) {
        if (tick == 0) revert InvalidTick();

        Position.Info storage position = positions.get(msg.sender, tick);

        amountS = amountSRequested > position.tokensOwed ? position.tokensOwed : amountSRequested;

        if (amountS > 0) {
            position.tokensOwed -= amountS;
            SafeTransferLib.safeTransfer(ERC20(Pair(pair).speculative()), to, amountS);
        }

        emit Collect(msg.sender, to, amountS);
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
                             STATE CACHE
    //////////////////////////////////////////////////////////////*/

    struct StateCache {
        uint256 currentLiquidity;
        uint256 interestNumerator;
        uint256 totalLiquidityBorrowed;
        uint16 currentTick;
    }

    function loadCache() private view returns (StateCache memory) {
        return
            StateCache({
                currentTick: currentTick,
                currentLiquidity: currentLiquidity,
                interestNumerator: interestNumerator,
                totalLiquidityBorrowed: totalLiquidityBorrowed
            });
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
                         INTERNAL LIQUIDITY LOGIC
    //////////////////////////////////////////////////////////////*/

    function updateTick(uint16 tick, int256 liquidityDelta) private {
        Tick.Info storage info = ticks[tick];

        bool init = info.liquidity == 0;
        info.liquidity = LiquidityMath.addDelta(info.liquidity, liquidityDelta);
        bool uninit = info.liquidity == 0;

        if (init) {
            uint16 below = tickBitMap.below(tick);
            if (below != 0) {
                uint16 above = ticks[below].next;
                console2.log("insert", tick, below, above);
                info.prev = below;
                info.next = above;
                ticks[below].next = tick;
                ticks[above].prev = tick;
            }

            tickBitMap.flipTick(tick, true);
        } else if (uninit) {
            uint16 below = info.prev;
            uint16 above = info.next;
            ticks[below].next = above;
            ticks[above].prev = below;

            tickBitMap.flipTick(tick, false);
            delete ticks[tick];
        }
    }

    function increaseCurrentLiquidity(uint256 liquidity, StateCache memory cache) private view {
        Tick.Info memory currentTickInfo = ticks[cache.currentTick];

        // amount of liquidity in this tick available
        uint256 remainingCurrentLiquidity = currentTickInfo.liquidity - cache.currentLiquidity;
        // amount of pair lp tokens to be added
        uint256 remainingLP = liquidity;

        while (true) {
            if (remainingCurrentLiquidity >= remainingLP) {
                break;
            } else {
                if (cache.currentTick == MaxTick) revert CompleteUtilizationError();

                cache.interestNumerator += cache.currentTick * remainingCurrentLiquidity;
                cache.currentTick = currentTickInfo.next;

                currentTickInfo = ticks[cache.currentTick];
                remainingLP -= remainingCurrentLiquidity;
                remainingCurrentLiquidity = currentTickInfo.liquidity;
            }
        }

        cache.interestNumerator += cache.currentTick * remainingLP;
        cache.currentLiquidity += remainingLP;
    }

    function decreaseCurrentLiquidity(uint256 liquidity, StateCache memory cache) private {
        Tick.Info memory currentTickInfo = ticks[cache.currentTick];

        uint256 remainingCurrentLiquidity = cache.currentLiquidity;
        uint256 remainingLP = liquidity;

        while (true) {
            if (remainingCurrentLiquidity >= remainingLP) {
                break;
            } else {
                cache.interestNumerator -= cache.currentTick * remainingCurrentLiquidity;
                cache.currentTick = currentTickInfo.prev;

                currentTickInfo = ticks[cache.currentTick];
                remainingLP -= remainingCurrentLiquidity;
                remainingCurrentLiquidity = currentTickInfo.liquidity;

                _accrueTickInterest(cache.currentTick);
            }
        }
        cache.interestNumerator -= cache.currentTick * remainingLP;
        cache.currentLiquidity = remainingCurrentLiquidity - remainingLP;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL INTEREST LOGIC
    //////////////////////////////////////////////////////////////*/

    function _accrueInterest(StateCache memory cache) private {
        if (totalSupply == 0) {
            lastUpdate = uint64(block.timestamp);
            return;
        }

        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed == 0 || cache.interestNumerator == 0) return;

        uint256 dilutionLPRequested = (cache.interestNumerator * timeElapsed) / (1 days * 10_000);
        uint256 dilutionLP = dilutionLPRequested > cache.totalLiquidityBorrowed
            ? cache.totalLiquidityBorrowed
            : dilutionLPRequested;

        uint256 dilutionSpeculative = convertLiquidityToAsset(dilutionLP);
        rewardPerINStored += (dilutionSpeculative * 1 ether) / cache.interestNumerator;

        _accrueTickInterest(currentTick);

        decreaseCurrentLiquidity(dilutionLP, cache);

        totalLiquidityBorrowed = cache.totalLiquidityBorrowed - dilutionLP;
        interestNumerator = cache.interestNumerator;
        currentLiquidity = cache.currentLiquidity;
        currentTick = cache.currentTick;
        lastUpdate = uint64(block.timestamp);

        emit AccrueInterest(timeElapsed, dilutionSpeculative, dilutionLP, rewardPerINStored);
    }

    function _accrueTickInterest(uint16 tick) private {
        if (tick > currentTick) revert UnutilizedAccrueError();

        Tick.Info storage tickInfo = ticks[tick];
        Tick.Info memory _tickInfo = tickInfo;

        uint256 tokensOwed = newTokensOwed(_tickInfo, tick);

        tickInfo.rewardPerINPaid = rewardPerINStored;
        if (tokensOwed > 0)
            tickInfo.tokensOwedPerLiquidity =
                _tickInfo.tokensOwedPerLiquidity +
                ((tokensOwed * 1 ether) / _tickInfo.liquidity);

        emit AccrueTickInterest(tick, rewardPerINStored, tokensOwed);
    }

    /// @dev assume global interest accrual is up to date
    function _accruePositionInterest(bytes32 id, uint16 tick) private {
        Position.Info storage position = positions[id];
        Position.Info memory _position = position;

        Tick.Info storage tickInfo = ticks[tick];
        Tick.Info memory _tickInfo = tickInfo;

        uint256 tokensOwed = newTokensOwed(_position, _tickInfo);

        position.rewardPerLiquidityPaid = _tickInfo.tokensOwedPerLiquidity;
        position.tokensOwed = _position.tokensOwed + tokensOwed;

        emit AccruePositionInterest(tick, id, _tickInfo.tokensOwedPerLiquidity, tokensOwed);
    }

    /// @dev Assumes reward per token stored is up to date
    function newTokensOwed(Tick.Info memory tickInfo, uint16 tick) private view returns (uint256) {
        if (tick > currentTick) return 0;

        uint256 liquidity = tickInfo.liquidity;
        if (currentTick == tick) {
            liquidity = currentLiquidity;
        }

        return (liquidity * tick * (rewardPerINStored - tickInfo.rewardPerINPaid)) / 1 ether;
    }

    /// @dev Assumes reward per token stored is up to date
    function newTokensOwed(Position.Info memory position, Tick.Info memory tickInfo) private pure returns (uint256) {
        uint256 liquidity = position.liquidity;

        return (liquidity * (tickInfo.tokensOwedPerLiquidity - position.rewardPerLiquidityPaid)) / (1 ether);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "./Factory.sol";
import { Pair } from "./Pair.sol";
import { ERC20 } from "./ERC20.sol";

import { IMintCallback } from "./interfaces/IMintCallback.sol";

import { Position } from "./libraries/Position.sol";
import { Tick } from "./libraries/Tick.sol";
import { TickBitMaps } from "./libraries/TickBitMaps.sol";
import { LiquidityMath } from "./libraries/LiquidityMath.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";

/// @notice A CFMM share lending engine
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
    /// @notice The maximum allowed interest rate tick
    uint16 public constant MaxTick = 10_000;

    /// @notice The contract that deployed the lendgine
    address public immutable factory;

    /// @notice The CFMM that is used in the lendgine
    address public immutable pair;

    /*//////////////////////////////////////////////////////////////
                          LENDGINE STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(bytes32 => Position.Info) public positions;

    mapping(uint16 => Tick.Info) public ticks;

    /// @notice BitMap used for keeping track of which tick contain >0 liquidity
    TickBitMaps.TickBitMap public tickBitMap;

    /// @notice The liquidity in the `currentTick`
    uint256 public currentLiquidity;

    /// @notice The sum of tick * borrow liquidity for all borrowed liquidity
    uint256 public interestNumerator;

    /// @notice The currently borrowed liquidity by borrowers
    uint256 public totalLiquidityBorrowed;

    /// @notice The amount of speculative assert rewarded to each unit of `interestNumerator` scaled by one ether
    uint256 public rewardPerINStored;

    /// @notice The timestamp at which interest was last accrued
    uint64 public lastUpdate;

    /// @notice The index of the highest tick that is being borrowed from
    /// @dev A value of 0 corresponds to an uninitialized state
    uint16 public currentTick;

    /*//////////////////////////////////////////////////////////////
                           REENTRANCY LOGIC
    //////////////////////////////////////////////////////////////*/

    uint8 private locked = 1;

    modifier lock() virtual {
        if (locked != 1) revert ReentrancyError();

        locked = 2;

        _;

        locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() ERC20() {
        factory = msg.sender;

        pair = address(new Pair{ salt: keccak256(abi.encode(address(this))) }(msg.sender));
    }

    /*//////////////////////////////////////////////////////////////
                            MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a position with amountS `speculative` tokens as collateral and `pair` CFMM share
    /// as debt, exactly replicating the desired payoff
    /// @dev This function uses a callback architecture capable of flash-minting
    /// @param to The address to mint the position to
    /// @param amountS The amount of `speculative` tokens to use as collateral, which determines
    /// the size of the position
    /// @param data Any data that should be passed through to the callback
    /// @return shares The size of the position that was sent to `to`
    function mint(
        address to,
        uint256 amountS,
        bytes calldata data
    ) external lock returns (uint256 shares) {
        StateCache memory cache = loadCache();

        _accrueInterest(cache);

        if (tickBitMap.firstTick == 0) revert CompleteUtilizationError();

        uint256 liquidity = convertAssetToLiquidity(amountS);
        shares = convertLiquidityToShare(liquidity);

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
    }

    /// @notice Burns a position, paying back debt and refunding collateral to the `to` address
    /// @dev The position that is to be burned should be sent to this contract before invoking this function
    /// @dev This assumes there is at least the amount of debt that is owed by this position
    /// @param to The address to send the unlocked collateral to
    /// @return amountS The amount of `speculative` tokens that have been sent to the `to` address
    function burn(address to) external lock returns (uint256 amountS) {
        StateCache memory cache = loadCache();

        _accrueInterest(cache);

        uint256 shares = balanceOf[address(this)];
        uint256 liquidity = convertShareToLiquidity(shares);
        amountS = convertLiquidityToAsset(liquidity);

        if (liquidity == 0) revert InsufficientOutputError();

        decreaseCurrentLiquidity(liquidity, cache);

        interestNumerator = cache.interestNumerator;
        totalLiquidityBorrowed = cache.totalLiquidityBorrowed - liquidity;
        currentLiquidity = cache.currentLiquidity;
        currentTick = cache.currentTick;

        _burn(address(this), shares);
        Pair(pair).removeBuffer(liquidity);
        TransferHelper.safeTransfer(Pair(pair).speculative(), to, amountS);

        emit Burn(msg.sender, amountS, shares, liquidity, to);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit CFMM shares from the `pair` to be lent out
    /// @dev The appropriate position should be minted in the pair contract before invoking this function
    /// @param to The address for which the deposit will be owned by
    /// @param tick The interest rate tick at which the liquidity can be lent out
    function deposit(address to, uint16 tick) external lock {
        StateCache memory cache = loadCache();

        uint256 liquidity = Pair(pair).buffer();

        if (liquidity == 0) revert InsufficientOutputError();
        if (tick == 0 || tick > MaxTick) revert InvalidTick();

        bytes32 id = Position.getID(to, tick);

        bool utilized = (cache.currentTick == tick && cache.currentLiquidity > 0) || (tick < cache.currentTick);
        if (utilized) {
            _accrueInterest(cache);
            if (tick != cache.currentTick) _accrueTickInterest(tick, cache);
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
        }

        Pair(pair).removeBuffer(liquidity);
        emit Deposit(msg.sender, liquidity, tick, to);
    }

    /// @notice Withdraw CFMM shares from the lending engine
    /// @dev The shares must still be withdrawn from the `pair`
    /// @param tick The tick at which to remove shares
    /// @param liquidity The amount of liquidity to remove
    function withdraw(uint16 tick, uint256 liquidity) external lock {
        StateCache memory cache = loadCache();

        if (liquidity == 0) revert InsufficientOutputError();
        if (tick == 0 || tick > MaxTick) revert InvalidTick();

        bytes32 id = Position.getID(msg.sender, tick);
        Position.Info memory positionInfo = positions.get(msg.sender, tick);
        Tick.Info memory tickInfo = ticks[tick];

        if (liquidity > positionInfo.liquidity) revert InsufficientPositionError();

        if ((cache.currentTick == tick && cache.currentLiquidity > 0) || (tick < cache.currentTick)) {
            _accrueInterest(cache);
            if (tick != cache.currentTick) _accrueTickInterest(tick, cache);
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

    /// @notice Calculates the interest rate and amount of interest that has gathered since the last update,
    /// then charges the borrowers and pays the lenders
    /// @dev Only positive interest rates are allowed
    function accrueInterest() external lock {
        StateCache memory cache = loadCache();
        _accrueInterest(cache);
    }

    /// @notice Calculates the interest accrued by a specific tick
    function accrueTickInterest(uint16 tick) external lock {
        if (tick == 0 || tick > MaxTick) revert InvalidTick();
        StateCache memory cache = loadCache();

        _accrueInterest(cache);
        if (tick != currentTick) _accrueTickInterest(tick, cache);
    }

    /// @notice Calculates the interest accrued by a specific postion
    /// @dev msg.sender is used to calculate the owner of the position
    /// @param tick The tick index of the position
    function accruePositionInterest(uint16 tick) external lock {
        if (tick == 0) revert InvalidTick();

        bytes32 id = Position.getID(msg.sender, tick);
        StateCache memory cache = loadCache();

        _accrueInterest(cache);
        if (tick != currentTick) _accrueTickInterest(tick, cache);
        _accruePositionInterest(id, tick);
    }

    /// @notice Collects tokens owed to a postion
    /// @dev msg.sender is used to calculative the owner of the position
    /// @param to The address to send the collected tokens to
    /// @param tick The tick index of the position
    /// @param amountSRequested How much `speculative` tokens should be withdrawn from the tokens owed
    function collect(
        address to,
        uint16 tick,
        uint256 amountSRequested
    ) external lock returns (uint256 amountS) {
        if (tick == 0 || tick > MaxTick) revert InvalidTick();

        Position.Info storage position = positions.get(msg.sender, tick);

        amountS = amountSRequested > position.tokensOwed ? position.tokensOwed : amountSRequested;

        if (amountS > 0) {
            position.tokensOwed -= amountS;
            TransferHelper.safeTransfer(Pair(pair).speculative(), to, amountS);
        }

        emit Collect(msg.sender, to, amountS);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Convert `pair` liquidity shares to amount of replicating derivative shares
    function convertLiquidityToShare(uint256 liquidity) public view returns (uint256) {
        uint256 _totalLiquidityBorrowed = totalLiquidityBorrowed;
        return _totalLiquidityBorrowed == 0 ? liquidity : (liquidity * totalSupply) / _totalLiquidityBorrowed;
    }

    /// @notice Convert replicating derivative shares to `pair` liquidity shares
    function convertShareToLiquidity(uint256 shares) public view returns (uint256) {
        return (totalLiquidityBorrowed * shares) / totalSupply;
    }

    /// @notice Convert `speculative` tokens to maximum amount of borrowable `pair` shares
    function convertAssetToLiquidity(uint256 assets) public view returns (uint256) {
        return (assets * 10**18) / (2 * Pair(pair).upperBound());
    }

    /// @notice Convert `pair` liquidity shares to minimum amount of `speculative` collateral
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

    /// @notice Returns the `speculative` balances of the lendgine
    /// @dev Not to be relied upon anywhere else because of a potential readonly reentracy
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

    /// @notice Updates a tick with the given liquidityDelta
    /// @param tick The index of the tick to update
    function updateTick(uint16 tick, int256 liquidityDelta) private {
        Tick.Info storage info = ticks[tick];

        bool init = info.liquidity == 0;
        info.liquidity = LiquidityMath.addDelta(info.liquidity, liquidityDelta);
        bool uninit = info.liquidity == 0;

        if (init) {
            if (tickBitMap.firstTick == 0) {
                tickBitMap.firstTick = tick;
            } else if (tick < tickBitMap.firstTick) {
                ticks[tickBitMap.firstTick].prev = tick;
                info.next = tickBitMap.firstTick;
                tickBitMap.firstTick = tick;
            } else {
                uint16 below = tickBitMap.below(tick);
                uint16 above = ticks[below].next;
                info.prev = below;
                info.next = above;
                ticks[below].next = tick;
                ticks[above].prev = tick;
            }

            tickBitMap.flipTick(tick, true);
        } else if (uninit) {
            if (tick == tickBitMap.firstTick) {
                tickBitMap.firstTick = info.next;
                ticks[info.next].prev = 0;
            } else {
                uint16 below = info.prev;
                uint16 above = info.next;
                ticks[below].next = above;
                ticks[above].prev = below;
            }

            tickBitMap.flipTick(tick, false);
            delete ticks[tick];
        }
    }

    function increaseCurrentLiquidity(uint256 liquidity, StateCache memory cache) private view {
        if (cache.currentTick == 0) cache.currentTick = tickBitMap.firstTick;

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

                _accrueTickInterest(cache.currentTick, cache);
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

        _accrueTickInterest(currentTick, cache);

        decreaseCurrentLiquidity(dilutionLP, cache);

        totalLiquidityBorrowed = cache.totalLiquidityBorrowed - dilutionLP;
        interestNumerator = cache.interestNumerator;
        currentLiquidity = cache.currentLiquidity;
        currentTick = cache.currentTick;
        lastUpdate = uint64(block.timestamp);

        emit AccrueInterest(timeElapsed, dilutionSpeculative, dilutionLP, rewardPerINStored);
    }

    function _accrueTickInterest(uint16 tick, StateCache memory cache) private {
        if (tick > cache.currentTick || (tick == cache.currentTick && cache.currentLiquidity == 0))
            revert UnutilizedAccrueError();

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

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.4;

import { Factory } from "./Factory.sol";

import { IMintCallback } from "./interfaces/IMintCallback.sol";

import { Position } from "./libraries/Position.sol";

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import "forge-std/console2.sol";

/// @notice A general purpose funding rate engine
/// @author Kyle Scott (https://github.com/kyscott18/kyleswap2.5/blob/main/src/Pair.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol)
/// and Primitive (https://github.com/primitivefinance/rmm-core/blob/main/contracts/PrimitiveEngine.sol)
contract Lendgine is ERC20 {
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address indexed sender, address indexed to, uint256 amountSpeculative, uint256 amountShares);

    event Burn(address indexed sender, address indexed to, uint256 amountShares, uint256 amountSpeculative);

    event MintMaker(address indexed sender, address indexed to, uint256 amountLP);

    event BurnMaker(address indexed sender, address indexed to, uint256 amountLP);

    event AccrueInterest();

    event AccrueMakerInterest();

    event Collect(address indexed owner, address indexed to, uint256 amountBase);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ReentrancyError();

    error BalanceReturnError();

    error InsufficientInputError();

    error InsufficientOutputError();

    error CompleteUtilizationError();

    error InsufficientPositionError();

    error UnutilizedAccrueError();

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public immutable upperBound;

    address public immutable factory;

    address public immutable speculativeToken;

    address public immutable lpToken;

    uint8 public constant RATE = 4; // bips per day

    /*//////////////////////////////////////////////////////////////
                          LENDGINE STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(bytes32 => Position.Info) public positions;

    bytes32 public lastPosition;

    bytes32 public currentPosition;

    uint256 public currentLiquidity;

    uint256 public totalLPUtilized;

    uint256 public rewardPerTokenStored;

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

    constructor() ERC20("Numoen Lendgine", "NLNDG", 18) {
        factory = msg.sender;

        (speculativeToken, lpToken, upperBound) = Factory(msg.sender).parameters();
    }

    /*//////////////////////////////////////////////////////////////
                            LENDGINE LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint(
        address recipient,
        uint256 amountSpeculative,
        bytes calldata data
    ) external lock returns (uint256) {
        // _accrueInterest();

        if (currentPosition == bytes32(0)) revert CompleteUtilizationError();

        // amount of LP to be borrowed
        uint256 lpAmount = lpForSpeculative(amountSpeculative);

        // amount of shares to award the recipient
        uint256 totalLPAmount = totalLPUtilized;
        uint256 _totalSupply = totalSupply;
        uint256 amountShares = totalLPAmount != 0 ? (lpAmount * _totalSupply) / totalLPAmount : lpAmount;

        if (amountShares == 0) revert InsufficientOutputError();

        // gather speculative tokens from makers
        increaseCurrentLiquidity(lpAmount);
        totalLPUtilized += lpAmount;

        _mint(recipient, amountShares); // optimistically mint

        SafeTransferLib.safeTransfer(ERC20(lpToken), recipient, lpAmount);

        uint256 balanceBefore = balanceSpeculative();
        IMintCallback(msg.sender).MintCallback(true, amountSpeculative, data);
        uint256 balanceAfter = balanceSpeculative();

        if (balanceAfter < balanceBefore + amountSpeculative) revert InsufficientInputError();

        emit Mint(msg.sender, recipient, amountSpeculative, amountShares);

        return amountShares;
    }

    function burn(address recipient, bytes calldata data) external lock {
        // _accrueInterest();

        uint256 amountShares = balanceOf[address(this)];

        uint256 amountLP = (amountShares * totalLPUtilized) / totalSupply;

        if (amountLP == 0) revert InsufficientOutputError();

        uint256 amountSpeculative = speculativeForLP(amountLP);

        decreaseCurrentLiquidity(amountLP);

        uint256 balanceBefore = balanceLP();
        IMintCallback(msg.sender).MintCallback(false, amountLP, data);
        uint256 balanceAfter = balanceLP();

        if (balanceAfter < balanceBefore + amountLP) revert InsufficientInputError();

        _burn(address(this), amountShares);

        SafeTransferLib.safeTransfer(ERC20(speculativeToken), recipient, amountSpeculative);

        emit Burn(msg.sender, recipient, amountShares, amountSpeculative);
    }

    // TODO: there is no access restriction so anyone can mint for someone else,
    // bumping them to the end of the positions queue
    function mintMaker(
        address recipient,
        uint256 amountLP,
        bytes calldata data
    ) external lock {
        Position.Info memory existing = positions.get(recipient);
        bytes32 id = Position.getId(recipient);

        if (amountLP == 0) revert InsufficientOutputError();

        uint256 utilizedLP;
        if (currentPosition == id) {
            utilizedLP = currentLiquidity;

            currentLiquidity = 0;
            currentPosition = positions[currentPosition].next;
        } else if (existing.utilized) {
            utilizedLP = existing.liquidity;
        }

        // if (utilized) {
        //     _accrueInterest();
        //     _accrueMakerInterest(id);
        // }

        positions.remove(id);

        // uint256 tokensOwed = newTokensOwed(existing);

        positions.append(
            id,
            lastPosition,
            Position.Info({
                liquidity: amountLP,
                tokensOwed: existing.tokensOwed,
                rewardPerTokenPaid: rewardPerTokenStored,
                next: bytes32(0),
                previous: bytes32(0),
                utilized: false
            })
        );

        // Replace if we removed utilized liquidity
        if (utilizedLP > 0) {
            increaseCurrentLiquidity(utilizedLP);
        }

        if (currentPosition == bytes32(0)) {
            currentPosition = id;
        }

        // Receive tokens and update global variables
        uint256 balanceBefore = balanceLP();
        IMintCallback(msg.sender).MintCallback(false, amountLP, data);
        uint256 balanceAfter = balanceLP();

        if (balanceAfter < balanceBefore + amountLP) revert InsufficientInputError();

        lastPosition = id;

        emit MintMaker(msg.sender, recipient, amountLP);
    }

    function burnMaker(address recipient, uint256 amountLP) external lock {
        Position.Info memory existing = positions.get(msg.sender);
        bytes32 id = Position.getId(recipient);

        // bool utilized = (currentPosition == id && currentLiquidity > 0) || (existing.utilized && currentPosition != id);

        // if (utilized) {
        //     _accrueInterest();
        //     _accrueMakerInterest(id);
        // }

        if (amountLP == 0) revert InsufficientOutputError();

        uint256 utilizedLP;

        if (currentPosition == id) {
            if (currentLiquidity > existing.liquidity - amountLP) {
                utilizedLP = currentLiquidity - (existing.liquidity - amountLP);
            }

            if (amountLP == existing.liquidity) {
                // if fully removing position
                // TODO: write to stack instead
                currentLiquidity = 0;
                currentPosition = positions[currentPosition].next;
            }
        } else if (existing.utilized) {
            utilizedLP = amountLP;
        }

        if (amountLP == 0) revert InsufficientOutputError();

        // Remove position from the data structure
        if (amountLP < existing.liquidity) {
            if (currentPosition == id && currentLiquidity > existing.liquidity - amountLP)
                currentLiquidity = existing.liquidity - amountLP;
            positions.get(msg.sender).update(-int256(amountLP));
        } else if (amountLP == existing.liquidity) {
            (uint256 tokensOwed, bytes32 previous) = positions.remove(Position.getId(recipient));
            // if (tokensOwed > 0) SafeTransferLib.safeTransfer(ERC20(base), recipient, tokensOwed);

            if (lastPosition == id) {
                lastPosition = previous;
            }
        } else {
            revert InsufficientPositionError();
        }

        // need to add as many speculative tokens as we withdrew
        // Replace if we removed utilized liquidity
        if (utilizedLP > 0) {
            increaseCurrentLiquidity(utilizedLP);
        }

        SafeTransferLib.safeTransfer(ERC20(lpToken), recipient, amountLP);

        emit BurnMaker(msg.sender, recipient, amountLP);
    }

    function accrueInterest() external lock {
        _accrueInterest();
    }

    function accrueMakerInterest(bytes32 id) external lock {
        _accrueInterest();
        _accrueMakerInterest(id);
    }

    function collectMaker(address recipient) external lock returns (uint256 collectedTokens) {
        Position.Info storage position = positions.get(msg.sender);

        collectedTokens = position.tokensOwed;

        if (collectedTokens == 0) revert InsufficientOutputError();

        position.tokensOwed = 0;

        SafeTransferLib.safeTransfer(ERC20(speculativeToken), recipient, collectedTokens);

        emit Collect(msg.sender, recipient, collectedTokens);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW
    //////////////////////////////////////////////////////////////*/

    function balanceSpeculative() public view returns (uint256) {
        bool success;
        bytes memory data;

        (success, data) = speculativeToken.staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("balanceOf(address)"))), address(this))
        );
        if (!success || data.length < 32) revert BalanceReturnError();

        return abi.decode(data, (uint256));
    }

    function balanceLP() public view returns (uint256) {
        bool success;
        bytes memory data;

        (success, data) = lpToken.staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("balanceOf(address)"))), address(this))
        );
        if (!success || data.length < 32) revert BalanceReturnError();

        return abi.decode(data, (uint256));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Current position is assumed to be valid
    function increaseCurrentLiquidity(uint256 amountLP) private {
        bytes32 currentId = currentPosition;
        Position.Info memory currentPositionInfo = positions[currentId];

        // amount of speculative in this tick available
        uint256 remainingCurrentLiquidity = currentPositionInfo.liquidity - currentLiquidity;
        uint256 remainingLP = amountLP; // amount of lp to be added

        while (true) {
            if (remainingCurrentLiquidity >= remainingLP) {
                break;
            } else {
                if (!currentPositionInfo.utilized) positions[currentId].utilized = true;

                // alter the amount of liquidity the user has
                // positions[currentId].liquidity =
                //     positions[currentId].liquidity -
                //     remainingCurrentLiquidity +
                //     (remainingCurrentLiquidity * liquidityPerSpeculative) /
                //     1 ether;

                currentId = currentPositionInfo.next;
                if (currentId == bytes32(0)) revert CompleteUtilizationError();
                currentPositionInfo = positions[currentId];

                remainingLP -= remainingCurrentLiquidity;
                remainingCurrentLiquidity = currentPositionInfo.liquidity;
            }
        }
        if (!currentPositionInfo.utilized && remainingLP != 0) positions[currentId].utilized = true;

        // // alter the amount of liquidity the user has
        // positions[currentId].liquidity =
        //     positions[currentId].liquidity -
        //     remainingSpeculative +
        //     (remainingSpeculative * liquidityPerSpeculative) /
        //     1 ether;

        currentPosition = currentId;
        currentLiquidity = remainingLP;
    }

    /// @dev assumed to never decrease past zero
    function decreaseCurrentLiquidity(uint256 amountLP) private {
        bytes32 currentId = currentPosition;
        Position.Info memory currentPositionInfo = positions[currentId];

        uint256 remainingCurrentLiquidity = currentLiquidity;
        uint256 remainingLP = amountLP;

        while (true) {
            if (remainingCurrentLiquidity >= remainingLP) {
                break;
            } else {
                positions[currentId].utilized = false;

                // if (currentPositionInfo.previous == bytes32(0)) revert OutOfBoundsError();

                // convert lp tokens to speculative
                // positions[currentId].liquidity =
                //     positions[currentId].liquidity -
                //     remainingCurrentLiquidity +
                //     (remainingCurrentLiquidity * speculativePerLiquidity) /
                //     1 ether;

                currentId = currentPositionInfo.previous;
                currentPositionInfo = positions[currentId];

                remainingLP -= remainingCurrentLiquidity;
                remainingCurrentLiquidity = currentPositionInfo.liquidity;

                // _accrueMakerInterest(currentId);
            }
        }
        if (remainingCurrentLiquidity == remainingLP) positions[currentId].utilized = false;

        // convert lp tokens to speculative
        // positions[currentId].liquidity =
        //     positions[currentId].liquidity -
        //     remainingShares +
        //     ((remainingShares) * speculativePerLiquidity) /
        //     1 ether;

        currentPosition = currentId;
        currentLiquidity = remainingCurrentLiquidity - remainingLP;
    }

    function _accrueInterest() private {
        if (totalSupply == 0) {
            lastUpdate = uint40(block.timestamp);
            return;
        }

        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed == 0 || totalLPUtilized == 0) return;

        // calculate how much must be removed
        uint256 dilutionLP = (totalLPUtilized * RATE * timeElapsed) / (1 days * 10_000);
        uint256 dilutionSpeculative = speculativeForLP(dilutionLP);

        decreaseCurrentLiquidity(dilutionLP);

        // Distribute to makers
        rewardPerTokenStored += (dilutionSpeculative * 1 ether) / totalLPUtilized;

        // // TODO: dilution > baseReserves;
        lastUpdate = uint40(block.timestamp);

        emit AccrueInterest();
    }

    /// @dev assume global interest accrual is up to date
    function _accrueMakerInterest(bytes32 id) private {
        Position.Info storage position = positions[id];
        Position.Info memory _position = position;

        if (!_position.utilized) revert UnutilizedAccrueError();

        uint256 tokensOwed = newTokensOwed(_position);

        position.rewardPerTokenPaid = rewardPerTokenStored;
        position.tokensOwed = _position.tokensOwed + tokensOwed;

        emit AccrueMakerInterest();
    }

    /// @dev Assumes reward per token stored is up to date
    function newTokensOwed(Position.Info memory position) private view returns (uint256) {
        // TODO: when maker liquidity is partially utilized
        if (!position.utilized) return 0;
        uint256 owed = (position.liquidity * (rewardPerTokenStored - position.rewardPerTokenPaid)) / 1 ether;
        return owed;
    }

    /*//////////////////////////////////////////////////////////////
                            NEW LOGIC
    //////////////////////////////////////////////////////////////*/

    function speculativeForLP(uint256 _lpAmount) public view returns (uint256) {
        return (2 * _lpAmount * upperBound) / 1 ether;
    }

    function lpForSpeculative(uint256 _speculativeAmount) public view returns (uint256) {
        return (_speculativeAmount * 1 ether) / (2 * upperBound);
    }
}

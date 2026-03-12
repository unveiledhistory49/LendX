// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {IAToken} from "../interfaces/IAToken.sol";
import {AToken} from "../tokens/AToken.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";

/// @title SupplyLogic
/// @author LendX Protocol
/// @notice Library implementing supply and withdraw operations for the LendingPool
/// @dev CEI pattern: Checks (ValidationLogic), Effects (index/state updates), Interactions (transfers)
///      All functions are `internal` so they are inlined into the calling contract,
///      preserving correct `msg.sender` and `address(this)` context.
library SupplyLogic {
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    // ============================================================
    //                       EVENTS
    // ============================================================

    event Supply(address indexed asset, address indexed user, address indexed onBehalfOf, uint256 amount);
    event Withdraw(address indexed asset, address indexed user, address indexed to, uint256 amount);

    // ============================================================
    //                   LOGIC FUNCTIONS
    // ============================================================

    /// @notice Executes the supply operation
    /// @dev Mints aTokens to onBehalfOf scaled by the current liquidity index.
    ///      The actual token transfer happens last (CEI pattern).
    /// @param reserve The reserve data for the supplied asset
    /// @param asset The address of the underlying ERC-20 token
    /// @param amount The amount to supply
    /// @param onBehalfOf The address that will receive the aTokens
    /// @param userSuppliedAssets Storage mapping to track user's supplied assets
    function executeSupply(
        ILendingPool.ReserveData storage reserve,
        address asset,
        uint256 amount,
        address onBehalfOf,
        mapping(address => bool) storage userSuppliedAssets
    ) internal {
        // EFFECTS: Mint aTokens (scaled by liquidity index)
        AToken aToken = AToken(reserve.aTokenAddress);
        bool isFirstMint = aToken.mint(onBehalfOf, amount, reserve.liquidityIndex);

        if (isFirstMint) {
            userSuppliedAssets[asset] = true;
        }

        // INTERACTIONS: Transfer underlying from user to pool
        // msg.sender is correct here because this is an internal function inlined into LendingPool
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit Supply(asset, msg.sender, onBehalfOf, amount);
    }

    /// @notice Executes the withdraw operation
    /// @dev Burns aTokens from user and transfers underlying to recipient.
    /// @param reserve The reserve data for the withdrawn asset
    /// @param asset The address of the underlying ERC-20 token
    /// @param amount The amount to withdraw
    /// @param to The address that will receive the underlying tokens
    /// @param userSuppliedAssets Storage mapping to track user's supplied assets
    function executeWithdraw(
        ILendingPool.ReserveData storage reserve,
        address asset,
        uint256 amount,
        address to,
        mapping(address => bool) storage userSuppliedAssets
    ) internal returns (uint256) {
        AToken aToken = AToken(reserve.aTokenAddress);

        // If withdrawing max, calculate actual amount from scaled balance
        uint256 userBalance = aToken.balanceOfWithIndex(msg.sender, reserve.liquidityIndex);
        if (amount == type(uint256).max) {
            amount = userBalance;
        }

        // EFFECTS: Burn aTokens
        aToken.burn(msg.sender, to, amount, reserve.liquidityIndex);

        // Check if user fully withdrew
        if (aToken.scaledBalanceOf(msg.sender) == 0) {
            userSuppliedAssets[asset] = false;
        }

        // INTERACTIONS: Transfer underlying to recipient
        IERC20(asset).safeTransfer(to, amount);

        emit Withdraw(asset, msg.sender, to, amount);

        return amount;
    }
}

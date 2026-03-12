// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {DebtToken} from "../tokens/DebtToken.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";

/// @title BorrowLogic
/// @author LendX Protocol
/// @notice Library implementing borrow and repay operations for the LendingPool
/// @dev CEI pattern: Checks (ValidationLogic), Effects (debt token mint/burn), Interactions (transfers)
///      All functions are `internal` so they are inlined into the calling contract,
///      preserving correct `msg.sender` and `address(this)` context.
library BorrowLogic {
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    // ============================================================
    //                       EVENTS
    // ============================================================

    event Borrow(address indexed asset, address indexed user, uint256 amount);
    event Repay(address indexed asset, address indexed user, address indexed onBehalfOf, uint256 amount);

    // ============================================================
    //                   LOGIC FUNCTIONS
    // ============================================================

    /// @notice Executes the borrow operation
    /// @dev Mints debt tokens to the borrower scaled by the variable borrow index,
    ///      then transfers the underlying asset to the borrower.
    /// @param reserve The reserve data for the borrowed asset
    /// @param asset The address of the underlying ERC-20 token to borrow
    /// @param amount The amount to borrow
    /// @param user The address of the borrower
    /// @param userBorrowedAssets Storage mapping to track user's borrowed assets
    function executeBorrow(
        ILendingPool.ReserveData storage reserve,
        address asset,
        uint256 amount,
        address user,
        mapping(address => bool) storage userBorrowedAssets
    ) internal {
        DebtToken debtToken = DebtToken(reserve.debtTokenAddress);

        // EFFECTS: Mint debt tokens (scaled by variable borrow index)
        bool isFirstBorrow = debtToken.mint(user, amount, reserve.variableBorrowIndex);

        if (isFirstBorrow) {
            userBorrowedAssets[asset] = true;
        }

        // INTERACTIONS: Transfer underlying to borrower
        IERC20(asset).safeTransfer(user, amount);

        emit Borrow(asset, user, amount);
    }

    /// @notice Executes the repay operation
    /// @dev Burns debt tokens from the borrower, with overpayment handling.
    ///      If amount exceeds outstanding debt, only the debt amount is repaid.
    /// @param reserve The reserve data for the repaid asset
    /// @param asset The address of the underlying ERC-20 token
    /// @param amount The amount to repay (use type(uint256).max for full repayment)
    /// @param onBehalfOf The address of the user whose debt is being repaid
    /// @param userBorrowedAssets Storage mapping to track user's borrowed assets
    /// @return actualRepayAmount The actual amount repaid after capping
    function executeRepay(
        ILendingPool.ReserveData storage reserve,
        address asset,
        uint256 amount,
        address onBehalfOf,
        mapping(address => bool) storage userBorrowedAssets
    ) internal returns (uint256 actualRepayAmount) {
        DebtToken debtToken = DebtToken(reserve.debtTokenAddress);

        // Calculate current debt
        uint256 currentDebt = debtToken.balanceOfWithIndex(onBehalfOf, reserve.variableBorrowIndex);

        // Handle overpayment / full repayment
        if (amount == type(uint256).max || amount > currentDebt) {
            actualRepayAmount = currentDebt;
        } else {
            actualRepayAmount = amount;
        }

        // EFFECTS: Burn debt tokens
        debtToken.burn(onBehalfOf, actualRepayAmount, reserve.variableBorrowIndex);

        // Check if fully repaid
        if (debtToken.scaledBalanceOf(onBehalfOf) == 0) {
            userBorrowedAssets[asset] = false;
        }

        // INTERACTIONS: Transfer underlying from payer to pool
        IERC20(asset).safeTransferFrom(msg.sender, address(this), actualRepayAmount);

        emit Repay(asset, msg.sender, onBehalfOf, actualRepayAmount);
    }
}

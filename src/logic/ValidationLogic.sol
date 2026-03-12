// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";

/// @title ValidationLogic
/// @author LendX Protocol
/// @notice Library implementing all pre-condition validation checks for LendingPool operations
/// @dev All checks are done here, keeping the main logic libraries focused on state changes.
///      Every error includes the relevant asset address for production diagnostics.
library ValidationLogic {
    using WadRayMath for uint256;

    // ============================================================
    //                       ERRORS
    // ============================================================

    error Validation__InvalidAmount();
    error Validation__AssetNotActive(address asset);
    error Validation__AssetFrozen(address asset);
    error Validation__BorrowingNotEnabled(address asset);
    error Validation__InsufficientBalance(uint256 available, uint256 requested);
    error Validation__HealthFactorTooLow(uint256 healthFactor);
    error Validation__InsufficientCollateral(uint256 available, uint256 required);
    error Validation__PositionHealthy(uint256 healthFactor);
    error Validation__SelfLiquidation();
    error Validation__InvalidDebtToCover();

    // ============================================================
    //                    VALIDATION FUNCTIONS
    // ============================================================

    /// @notice Validates the supply parameters
    /// @param reserve The reserve data for the supplied asset
    /// @param amount The amount to supply
    /// @param asset The address of the asset being supplied
    function validateSupply(
        ILendingPool.ReserveData storage reserve,
        uint256 amount,
        address asset
    ) internal view {
        if (amount == 0) revert Validation__InvalidAmount();
        if (!reserve.active) revert Validation__AssetNotActive(asset);
        if (reserve.frozen) revert Validation__AssetFrozen(asset);
    }

    /// @notice Validates the withdraw parameters
    /// @param reserve The reserve data for the withdrawn asset
    /// @param amount The amount to withdraw
    /// @param userBalance The user's current aToken balance
    /// @param asset The address of the asset being withdrawn
    function validateWithdraw(
        ILendingPool.ReserveData storage reserve,
        uint256 amount,
        uint256 userBalance,
        address asset
    ) internal view {
        if (amount == 0) revert Validation__InvalidAmount();
        if (!reserve.active) revert Validation__AssetNotActive(asset);
        if (userBalance < amount) revert Validation__InsufficientBalance(userBalance, amount);
    }

    /// @notice Validates the borrow parameters
    /// @param reserve The reserve data for the borrowed asset
    /// @param amount The amount to borrow
    /// @param userCollateralUSD The user's total collateral in USD (WAD)
    /// @param userDebtUSD The user's total debt in USD (WAD) after the requested borrow
    /// @param ltv The weighted average LTV (basis points)
    /// @param asset The address of the asset being borrowed
    function validateBorrow(
        ILendingPool.ReserveData storage reserve,
        uint256 amount,
        uint256 userCollateralUSD,
        uint256 userDebtUSD,
        uint256 ltv,
        address asset
    ) internal view {
        if (amount == 0) revert Validation__InvalidAmount();
        if (!reserve.active) revert Validation__AssetNotActive(asset);
        if (reserve.frozen) revert Validation__AssetFrozen(asset);
        if (!reserve.borrowingEnabled) revert Validation__BorrowingNotEnabled(asset);

        // Calculate maximum borrow: collateralUSD * ltv / 10000
        uint256 maxBorrowUSD = (userCollateralUSD * ltv) / 10_000;
        if (userDebtUSD > maxBorrowUSD) {
            revert Validation__InsufficientCollateral(maxBorrowUSD, userDebtUSD);
        }
    }

    /// @notice Validates the repay parameters
    /// @param reserve The reserve data for the repaid asset
    /// @param amount The amount to repay
    /// @param userDebt The user's outstanding debt for this asset
    /// @param asset The address of the asset being repaid
    function validateRepay(
        ILendingPool.ReserveData storage reserve,
        uint256 amount,
        uint256 userDebt,
        address asset
    ) internal view {
        if (amount == 0) revert Validation__InvalidAmount();
        if (!reserve.active) revert Validation__AssetNotActive(asset);
        if (userDebt == 0) revert Validation__InvalidAmount();
    }

    /// @notice Validates the liquidation parameters
    /// @param collateralReserve The reserve data for the collateral asset
    /// @param debtReserve The reserve data for the debt asset
    /// @param healthFactor The borrower's current health factor (WAD)
    /// @param debtToCover The amount of debt to cover
    /// @param liquidator The address performing the liquidation
    /// @param borrower The address being liquidated
    /// @param collateralAsset The address of the collateral asset
    /// @param debtAsset The address of the debt asset
    function validateLiquidation(
        ILendingPool.ReserveData storage collateralReserve,
        ILendingPool.ReserveData storage debtReserve,
        uint256 healthFactor,
        uint256 debtToCover,
        address liquidator,
        address borrower,
        address collateralAsset,
        address debtAsset
    ) internal view {
        if (!collateralReserve.active) revert Validation__AssetNotActive(collateralAsset);
        if (!debtReserve.active) revert Validation__AssetNotActive(debtAsset);
        if (healthFactor >= 1e18) revert Validation__PositionHealthy(healthFactor);
        if (debtToCover == 0) revert Validation__InvalidDebtToCover();
        if (liquidator == borrower) revert Validation__SelfLiquidation();
    }

    /// @notice Validates that withdrawn/borrowed changes don't break the health factor
    /// @param healthFactor The user's health factor after the operation (WAD)
    function validateHealthFactor(uint256 healthFactor) internal pure {
        if (healthFactor < 1e18) {
            revert Validation__HealthFactorTooLow(healthFactor);
        }
    }
}

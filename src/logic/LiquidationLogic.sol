// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {AToken} from "../tokens/AToken.sol";
import {DebtToken} from "../tokens/DebtToken.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";

/// @title LiquidationLogic
/// @author LendX Protocol
/// @notice Library implementing the liquidation engine with tiered bonus system
/// @dev The tiered bonus is a design improvement over Aave's fixed bonus —
///      severely underwater positions offer higher rewards to incentivize rapid liquidation.
///      Close factor is capped at 50% to prevent cascade liquidations.
///      All functions are `internal` so they are inlined into the calling contract.
library LiquidationLogic {
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    // ============================================================
    //                       CONSTANTS
    // ============================================================

    /// @notice Maximum percentage of debt that can be liquidated in a single call (50%)
    uint256 public constant CLOSE_FACTOR = 0.5e18; // WAD

    // ============================================================
    //                       STRUCTS
    // ============================================================

    /// @dev Packed parameters for executeLiquidation to avoid stack-too-deep
    struct LiquidationParams {
        address collateralAsset;
        address debtAsset;
        address borrower;
        uint256 debtToCover;
        uint256 healthFactor;
        address oracle;
    }

    // ============================================================
    //                       EVENTS
    // ============================================================

    event LiquidationCall(
        address indexed collateralAsset,
        address indexed debtAsset,
        address indexed borrower,
        uint256 debtToCover,
        uint256 collateralSeized,
        address liquidator
    );

    // ============================================================
    //                   LOGIC FUNCTIONS
    // ============================================================

    /// @notice Executes a liquidation
    /// @dev Flow: cap debt at close factor → calculate collateral to seize with
    ///      tiered bonus → burn borrower's debt → transfer collateral to liquidator
    /// @param collateralReserve The reserve data for the collateral asset
    /// @param debtReserve The reserve data for the debt asset
    /// @param params Packed liquidation parameters (to avoid stack-too-deep)
    function executeLiquidation(
        ILendingPool.ReserveData storage collateralReserve,
        ILendingPool.ReserveData storage debtReserve,
        LiquidationParams memory params
    ) internal {
        // 1. Cap debtToCover at close factor (50% of total debt)
        uint256 debtToCover = _capDebtToCover(debtReserve, params.borrower, params.debtToCover);

        // 2. Calculate collateral to seize with tiered bonus
        uint256 liquidationBonus = _getLiquidationBonus(params.healthFactor);
        uint256 collateralToSeize = _calcCollateralToSeize(
            params.collateralAsset, params.debtAsset, debtToCover, liquidationBonus, params.oracle
        );

        // 3. Cap collateral seizure at borrower's available collateral
        uint256 borrowerCollateral = AToken(collateralReserve.aTokenAddress)
            .balanceOfWithIndex(params.borrower, collateralReserve.liquidityIndex);

        if (collateralToSeize > borrowerCollateral) {
            collateralToSeize = borrowerCollateral;
            debtToCover = _calcDebtFromCollateral(
                params.collateralAsset, params.debtAsset, collateralToSeize, liquidationBonus, params.oracle
            );
        }

        // EFFECTS + INTERACTIONS
        _executeTransfers(collateralReserve, debtReserve, params, debtToCover, collateralToSeize);
    }

    // ============================================================
    //                  PRIVATE FUNCTIONS
    // ============================================================

    /// @dev Caps debt to cover at 50% of total debt (close factor)
    function _capDebtToCover(
        ILendingPool.ReserveData storage debtReserve,
        address borrower,
        uint256 debtToCover
    ) private view returns (uint256) {
        uint256 totalDebt = DebtToken(debtReserve.debtTokenAddress)
            .balanceOfWithIndex(borrower, debtReserve.variableBorrowIndex);
        uint256 maxLiquidatable = totalDebt.wadMul(CLOSE_FACTOR);
        return debtToCover > maxLiquidatable ? maxLiquidatable : debtToCover;
    }

    /// @dev Executes the token transfers for a liquidation
    function _executeTransfers(
        ILendingPool.ReserveData storage collateralReserve,
        ILendingPool.ReserveData storage debtReserve,
        LiquidationParams memory params,
        uint256 debtToCover,
        uint256 collateralToSeize
    ) private {
        // Burn borrower's debt tokens
        DebtToken(debtReserve.debtTokenAddress).burn(
            params.borrower, debtToCover, debtReserve.variableBorrowIndex
        );

        // Transfer collateral: burn from borrower, mint to liquidator
        AToken collateralAToken = AToken(collateralReserve.aTokenAddress);
        collateralAToken.burn(
            params.borrower, address(this), collateralToSeize, collateralReserve.liquidityIndex
        );
        collateralAToken.mint(msg.sender, collateralToSeize, collateralReserve.liquidityIndex);

        // Liquidator pays the debt
        IERC20(params.debtAsset).safeTransferFrom(msg.sender, address(this), debtToCover);

        emit LiquidationCall(
            params.collateralAsset,
            params.debtAsset,
            params.borrower,
            debtToCover,
            collateralToSeize,
            msg.sender
        );
    }

    /// @notice Determines the liquidation bonus based on how underwater the position is
    /// @dev Tiered system:
    ///      - healthFactor > 0.95: 5% bonus (10500 bps) — slightly underwater
    ///      - healthFactor > 0.80: 8% bonus (10800 bps) — moderately underwater
    ///      - healthFactor <= 0.80: 12% bonus (11200 bps) — severely underwater
    /// @param healthFactor The borrower's health factor (WAD)
    /// @return The liquidation bonus in basis points (10000 = 100%, 10500 = 105%)
    function _getLiquidationBonus(uint256 healthFactor) private pure returns (uint256) {
        if (healthFactor > 0.95e18) return 10_500; // 5% bonus
        if (healthFactor > 0.80e18) return 10_800; // 8% bonus
        return 11_200; // 12% bonus
    }

    /// @notice Calculates the amount of collateral to seize for a given debt amount
    function _calcCollateralToSeize(
        address collateralAsset,
        address debtAsset,
        uint256 debtToCover,
        uint256 liquidationBonus,
        address oracle
    ) private view returns (uint256) {
        uint256 debtPriceUSD = IPriceOracle(oracle).getAssetPrice(debtAsset);
        uint256 collateralPriceUSD = IPriceOracle(oracle).getAssetPrice(collateralAsset);

        uint256 debtValueUSD = debtToCover.wadMul(debtPriceUSD);
        uint256 collateralValueWithBonus = (debtValueUSD * liquidationBonus) / 10_000;

        return collateralValueWithBonus.wadDiv(collateralPriceUSD);
    }

    /// @notice Reverse calculation: debt amount from collateral amount
    function _calcDebtFromCollateral(
        address collateralAsset,
        address debtAsset,
        uint256 collateralAmount,
        uint256 liquidationBonus,
        address oracle
    ) private view returns (uint256) {
        uint256 debtPriceUSD = IPriceOracle(oracle).getAssetPrice(debtAsset);
        uint256 collateralPriceUSD = IPriceOracle(oracle).getAssetPrice(collateralAsset);

        uint256 collateralValueUSD = collateralAmount.wadMul(collateralPriceUSD);
        uint256 debtValue = (collateralValueUSD * 10_000) / liquidationBonus;

        return debtValue.wadDiv(debtPriceUSD);
    }
}

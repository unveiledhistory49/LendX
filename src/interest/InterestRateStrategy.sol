// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IInterestRateStrategy} from "../interfaces/IInterestRateStrategy.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";

/// @title InterestRateStrategy
/// @author LendX Protocol
/// @notice Implements a utilization-based two-slope interest rate model
/// @dev Modeled after Compound/Aave V3 rate curves with configurable parameters
///
/// Rate curve:
///   - Below optimal utilization: borrowRate = baseRate + (U / Uoptimal) × slope1
///   - Above optimal utilization: borrowRate = baseRate + slope1 + ((U - Uoptimal) / (1 - Uoptimal)) × slope2
///   - Supply rate: borrowRate × U × (1 - reserveFactor)
///
/// This creates the classic "hockey stick" curve that incentivizes keeping utilization near optimal.
contract InterestRateStrategy is IInterestRateStrategy {
    using WadRayMath for uint256;

    // ============================================================
    //                       CONSTANTS
    // ============================================================

    /// @notice Optimal utilization rate (80%) in RAY
    uint256 public constant override OPTIMAL_UTILIZATION = 0.80e27;

    /// @notice Base interest rate (0%) in RAY
    uint256 public constant override BASE_RATE = 0;

    /// @notice Rate slope below optimal utilization (4%) in RAY
    uint256 public constant override SLOPE_1 = 0.04e27;

    /// @notice Rate slope above optimal utilization (75%) in RAY
    uint256 public constant override SLOPE_2 = 0.75e27;

    /// @notice Protocol fee on interest earned (10%) in RAY
    uint256 public constant RESERVE_FACTOR = 0.10e27;

    // ============================================================
    //                   EXTERNAL FUNCTIONS
    // ============================================================

    /// @notice Calculates the interest rates based on utilization
    /// @dev Uses a two-slope model: gentle slope below optimal, steep slope above
    /// @param availableLiquidity The total available (unborrowed) liquidity in the reserve
    /// @param totalBorrows The total outstanding borrows from the reserve
    /// @return liquidityRate The current supply APY for depositors (RAY)
    /// @return borrowRate The current borrow APY for borrowers (RAY)
    function calculateInterestRates(
        uint256 availableLiquidity,
        uint256 totalBorrows
    ) external pure override returns (uint256 liquidityRate, uint256 borrowRate) {
        // If no borrows, both rates are zero
        if (totalBorrows == 0) {
            return (0, 0);
        }

        uint256 totalLiquidity = availableLiquidity + totalBorrows;

        // Calculate utilization rate: U = totalBorrows / totalLiquidity (in RAY)
        uint256 utilization = totalBorrows.rayDiv(totalLiquidity);

        if (utilization <= OPTIMAL_UTILIZATION) {
            // Below optimal: borrowRate = baseRate + (U / Uoptimal) × slope1
            borrowRate = BASE_RATE + utilization.rayMul(SLOPE_1).rayDiv(OPTIMAL_UTILIZATION);
        } else {
            // Above optimal: borrowRate = baseRate + slope1 + ((U - Uoptimal) / (1 - Uoptimal)) × slope2
            uint256 excessUtilization = utilization - OPTIMAL_UTILIZATION;
            uint256 maxExcessUtilization = WadRayMath.RAY - OPTIMAL_UTILIZATION;
            borrowRate = BASE_RATE + SLOPE_1 + excessUtilization.rayMul(SLOPE_2).rayDiv(maxExcessUtilization);
        }

        // Supply rate = borrowRate × utilization × (1 - reserveFactor)
        // This ensures the protocol takes its cut before distributing to suppliers
        liquidityRate = borrowRate.rayMul(utilization).rayMul(WadRayMath.RAY - RESERVE_FACTOR);
    }
}

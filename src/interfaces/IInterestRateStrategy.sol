// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IInterestRateStrategy
/// @notice Interface for the interest rate calculation strategy
interface IInterestRateStrategy {
    /// @notice Calculates the interest rates for a reserve based on utilization
    /// @dev Implements a two-slope utilization curve: gentle slope below optimal
    ///      utilization and steep slope above it (the "hockey stick" curve)
    /// @param availableLiquidity The total available liquidity in the reserve
    /// @param totalBorrows The total outstanding borrows
    /// @return liquidityRate The current supply rate (RAY)
    /// @return borrowRate The current borrow rate (RAY)
    function calculateInterestRates(
        uint256 availableLiquidity,
        uint256 totalBorrows
    ) external view returns (uint256 liquidityRate, uint256 borrowRate);

    /// @notice Returns the optimal utilization rate
    /// @return The optimal utilization in RAY
    function OPTIMAL_UTILIZATION() external view returns (uint256);

    /// @notice Returns the base interest rate
    /// @return The base rate in RAY
    function BASE_RATE() external view returns (uint256);

    /// @notice Returns the slope of the rate curve below optimal utilization
    /// @return The slope1 value in RAY
    function SLOPE_1() external view returns (uint256);

    /// @notice Returns the slope of the rate curve above optimal utilization
    /// @return The slope2 value in RAY
    function SLOPE_2() external view returns (uint256);
}

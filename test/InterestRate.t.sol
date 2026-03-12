// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {InterestRateStrategy} from "../src/interest/InterestRateStrategy.sol";
import {WadRayMath} from "../src/libraries/WadRayMath.sol";

/// @title InterestRateStrategyTest
/// @notice Tests for the two-slope interest rate model
/// @dev Tests boundary conditions at optimal utilization and extreme utilization
contract InterestRateStrategyTest is Test {
    using WadRayMath for uint256;

    InterestRateStrategy public strategy;

    function setUp() public {
        strategy = new InterestRateStrategy();
    }

    // ============================================================
    //                  CONSTRUCTOR / CONFIG TESTS
    // ============================================================

    function test_Constants() public view {
        assertEq(strategy.OPTIMAL_UTILIZATION(), 0.80e27);
        assertEq(strategy.BASE_RATE(), 0);
        assertEq(strategy.SLOPE_1(), 0.04e27);
        assertEq(strategy.SLOPE_2(), 0.75e27);
    }

    // ============================================================
    //                  RATE CALCULATION TESTS
    // ============================================================

    function test_ZeroUtilization() public view {
        // No borrows → 0% interest rate
        (uint256 liquidityRate, uint256 borrowRate) =
            strategy.calculateInterestRates(1000e18, 0);

        assertEq(borrowRate, 0, "Borrow rate should be 0 at 0% utilization");
        assertEq(liquidityRate, 0, "Liquidity rate should be 0 at 0% utilization");
    }

    function test_HalfOptimalUtilization() public view {
        // 40% utilization (half of optimal 80%)
        // Borrow rate = baseRate + (40/80) * slope1 = 0 + 0.5 * 4% = 2%
        uint256 totalLiquidity = 1000e18;
        uint256 totalBorrows = 400e18; // 40%

        (uint256 liquidityRate, uint256 borrowRate) =
            strategy.calculateInterestRates(totalLiquidity - totalBorrows, totalBorrows);

        assertApproxEqRel(borrowRate, 0.02e27, 0.01e18, "Borrow rate ~2% at 40% util");
        assertGt(liquidityRate, 0, "Liquidity rate should be positive");
    }

    function test_AtOptimalUtilization() public view {
        // 80% utilization = optimal
        // Borrow rate = baseRate + slope1 = 0 + 4% = 4%
        uint256 totalLiquidity = 1000e18;
        uint256 totalBorrows = 800e18;

        (uint256 liquidityRate, uint256 borrowRate) =
            strategy.calculateInterestRates(totalLiquidity - totalBorrows, totalBorrows);

        assertApproxEqRel(borrowRate, 0.04e27, 0.01e18, "Borrow rate should be ~4% at optimal");
    }

    function test_AboveOptimalUtilization() public view {
        // 90% utilization (above optimal 80%)
        // Borrow rate = baseRate + slope1 + ((90-80)/(100-80)) * slope2
        //             = 0 + 4% + (0.5) * 75% = 4% + 37.5% = 41.5%
        uint256 totalLiquidity = 1000e18;
        uint256 totalBorrows = 900e18;

        (uint256 liquidityRate, uint256 borrowRate) =
            strategy.calculateInterestRates(totalLiquidity - totalBorrows, totalBorrows);

        assertApproxEqRel(borrowRate, 0.415e27, 0.01e18, "Borrow rate ~41.5% at 90% util");
    }

    function test_FullUtilization() public view {
        // 100% utilization: available = 0, borrows = 1000
        // Borrow rate = baseRate + slope1 + slope2 = 0 + 4% + 75% = 79%
        (uint256 liquidityRate, uint256 borrowRate) =
            strategy.calculateInterestRates(0, 1000e18);

        assertApproxEqRel(borrowRate, 0.79e27, 0.01e18, "Borrow rate ~79% at 100% util");
    }

    function test_LiquidityRate_LessThanBorrowRate() public view {
        // Liquidity rate should always be <= borrow rate (because of reserve factor)
        (uint256 liquidityRate, uint256 borrowRate) =
            strategy.calculateInterestRates(200e18, 800e18);

        assertLe(liquidityRate, borrowRate, "Liquidity rate should be <= borrow rate");
    }

    // ============================================================
    //                    EDGE CASES
    // ============================================================

    function test_ZeroLiquidity_ZeroBorrows() public view {
        (uint256 liquidityRate, uint256 borrowRate) =
            strategy.calculateInterestRates(0, 0);

        assertEq(borrowRate, 0);
        assertEq(liquidityRate, 0);
    }

    // ============================================================
    //                    FUZZING TESTS
    // ============================================================

    function testFuzz_RatesAlwaysNonNegative(uint128 liquidity, uint128 borrows) public view {
        vm.assume(uint256(liquidity) + uint256(borrows) > 0);

        (uint256 liquidityRate, uint256 borrowRate) =
            strategy.calculateInterestRates(uint256(liquidity), uint256(borrows));

        assertGe(borrowRate, 0, "Borrow rate must be non-negative");
        assertGe(liquidityRate, 0, "Liquidity rate must be non-negative");
    }

    function testFuzz_BorrowRateMonotonicallyIncreasing(uint64 borrows1, uint64 borrows2) public view {
        uint256 totalLiquidity = 1000e18;
        uint256 b1 = uint256(borrows1) % totalLiquidity;
        uint256 b2 = uint256(borrows2) % totalLiquidity;

        if (b1 > b2) (b1, b2) = (b2, b1); // Ensure b1 <= b2

        (, uint256 rate1) = strategy.calculateInterestRates(totalLiquidity - b1, b1);
        (, uint256 rate2) = strategy.calculateInterestRates(totalLiquidity - b2, b2);

        assertGe(rate2, rate1, "Borrow rate should increase with utilization");
    }
}

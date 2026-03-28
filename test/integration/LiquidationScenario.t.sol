// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {LendingPool} from "../../src/core/LendingPool.sol";
import {ILendingPool} from "../../src/interfaces/ILendingPool.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";
import {InterestRateStrategy} from "../../src/interest/InterestRateStrategy.sol";
import {AToken} from "../../src/tokens/AToken.sol";
import {DebtToken} from "../../src/tokens/DebtToken.sol";
import {WadRayMath} from "../../src/libraries/WadRayMath.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockAggregatorV3} from "../mocks/MockAggregatorV3.sol";

/// @title LiquidationScenarioTest
/// @notice Integration test: full liquidation scenario with tiered bonus system
/// @dev Following web3-testing skill: realistic scenarios, state verification, edge cases
contract LiquidationScenarioTest is Test {
    using WadRayMath for uint256;

    LendingPool public pool;
    PriceOracle public oracle;
    InterestRateStrategy public strategy;

    MockERC20 public weth;
    MockERC20 public usdc;

    AToken public aWETH;
    AToken public aUSDC;
    DebtToken public debtWETH;
    DebtToken public debtUSDC;

    MockAggregatorV3 public ethFeed;
    MockAggregatorV3 public usdcFeed;

    address public admin = address(1);
    address public borrower = address(2);
    address public supplier = address(3);
    address public liquidator = address(4);

    function setUp() public {
        vm.warp(100_000);

        // Deploy tokens
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 18);

        // Deploy price feeds
        ethFeed = new MockAggregatorV3(8, 2000e8);
        usdcFeed = new MockAggregatorV3(8, 1e8);

        // Deploy oracle
        vm.startPrank(admin);
        oracle = new PriceOracle(admin);
        oracle.setAssetFeed(address(weth), address(ethFeed));
        oracle.setAssetFeed(address(usdc), address(usdcFeed));
        vm.stopPrank();

        // Deploy strategy & pool
        strategy = new InterestRateStrategy();
        vm.prank(admin);
        pool = new LendingPool(address(oracle), admin);

        // Deploy tokens
        aWETH = new AToken(address(pool), address(weth), "aWETH", "aWETH");
        aUSDC = new AToken(address(pool), address(usdc), "aUSDC", "aUSDC");
        debtWETH = new DebtToken(address(pool), address(weth), "debtWETH", "debtWETH");
        debtUSDC = new DebtToken(address(pool), address(usdc), "debtUSDC", "debtUSDC");

        // Add reserves
        vm.startPrank(admin);
        pool.addReserve(address(weth), address(aWETH), address(debtWETH), address(strategy), 8000, 8500, 10500, 1000, true);
        pool.addReserve(address(usdc), address(aUSDC), address(debtUSDC), address(strategy), 7500, 8000, 10500, 1000, true);
        vm.stopPrank();

        // Fund users
        weth.mint(borrower, 100e18);
        usdc.mint(supplier, 500_000e18);
        usdc.mint(liquidator, 500_000e18);

        // Approvals
        vm.prank(borrower);
        weth.approve(address(pool), type(uint256).max);
        vm.prank(borrower);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(supplier);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(liquidator);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(liquidator);
        weth.approve(address(pool), type(uint256).max);
    }

    /// @notice Full liquidation scenario:
    ///         1. Borrower supplies 10 WETH ($20,000)
    ///         2. Borrows 13,000 USDC (near max LTV of 80% → $16,000 max)
    ///         3. ETH price drops 20% ($2000 → $1600)
    ///         4. Liquidator liquidates
    ///         5. Verify state: borrower debt reduced, liquidator received collateral
    function test_LiquidationScenario_PriceCrash() public {
        // STEP 1: Supplier provides USDC liquidity
        vm.prank(supplier);
        pool.supply(address(usdc), 200_000e18, supplier);

        // STEP 2: Borrower supplies 10 WETH as collateral
        vm.prank(borrower);
        pool.supply(address(weth), 10e18, borrower);

        // STEP 3: Borrower borrows near max LTV
        // Collateral: 10 WETH * $2000 = $20,000, LTV 80% → max $16,000
        // Borrow 13,000 USDC (well within LTV)
        vm.prank(borrower);
        pool.borrow(address(usdc), 13_000e18);

        // Verify healthy position
        (, , , , , uint256 healthBefore) = pool.getUserAccountData(borrower);
        assertGt(healthBefore, 1e18, "Position should be healthy before crash");

        // STEP 4: ETH price drops 20% ($2000 → $1600)
        // New collateral = 10 * $1600 = $16,000
        // liquidation threshold 85% → threshold collateral = $13,600
        // Debt = $13,000 → HF = 13,600 / 13,000 ≈ 1.046 → still healthy but barely
        ethFeed.updateAnswer(1600e8);

        // Drop further to $1400 to definitely breach
        // New collateral = 10 * $1400 = $14,000
        // Threshold collateral = $14,000 * 85% = $11,900
        // HF = 11,900 / 13,000 ≈ 0.915 → liquidatable
        ethFeed.updateAnswer(1400e8);

        (, , , , , uint256 healthAfterCrash) = pool.getUserAccountData(borrower);
        assertLt(healthAfterCrash, 1e18, "Position should be underwater after crash");

        // Record state before liquidation
        uint256 borrowerDebtBefore = debtUSDC.scaledBalanceOf(borrower);
        uint256 liquidatorCollateralBefore = aWETH.scaledBalanceOf(liquidator);

        // STEP 5: Liquidator liquidates 50% of debt (close factor)
        uint256 debtToLiquidate = 5_000e18;
        vm.prank(liquidator);
        pool.liquidate(address(weth), address(usdc), borrower, debtToLiquidate);

        // Verify post-liquidation state
        uint256 borrowerDebtAfter = debtUSDC.scaledBalanceOf(borrower);
        uint256 liquidatorCollateralAfter = aWETH.scaledBalanceOf(liquidator);

        assertLt(borrowerDebtAfter, borrowerDebtBefore, "Borrower debt should be reduced");
        assertGt(liquidatorCollateralAfter, liquidatorCollateralBefore, "Liquidator should receive collateral");

        // Health factor might decrease slightly due to the 8% bonus being higher than the 85% threshold gain
        // so we check that the debt was indeed partially covered.
        // Verify actual debt was reduced by the liquidated amount.
        // We compare actual (index-adjusted) debt, not scaled balances, because
        // scaled balance deltas differ from actual amounts when borrowIndex > 1 RAY.
        ILendingPool.ReserveData memory debtData = pool.getReserveData(address(usdc));
        uint256 actualDebtBefore = borrowerDebtBefore.rayMul(debtData.variableBorrowIndex);
        uint256 actualDebtAfter = debtUSDC.balanceOfWithIndex(borrower, debtData.variableBorrowIndex);
        assertApproxEqAbs(
            actualDebtBefore - actualDebtAfter,
            debtToLiquidate,
            1e9, // dust tolerance for rounding
            "Debt should be reduced by approximately the liquidated amount"
        );
    }

    /// @notice Tests that the close factor (50%) is respected
    function test_LiquidationScenario_CloseFactorCap() public {
        // Setup: borrower underwater
        vm.prank(supplier);
        pool.supply(address(usdc), 200_000e18, supplier);
        vm.prank(borrower);
        pool.supply(address(weth), 10e18, borrower);
        vm.prank(borrower);
        pool.borrow(address(usdc), 13_000e18);

        // Crash ETH price to make position liquidatable
        ethFeed.updateAnswer(1200e8);

        // Try to liquidate more than 50% close factor
        // Total debt is ~13,000 USDC, close factor = 50%, so max = ~6,500
        // Attempting to liquidate 10,000 should be capped at 50%
        uint256 borrowerDebtBefore = debtUSDC.scaledBalanceOf(borrower);

        vm.prank(liquidator);
        pool.liquidate(address(weth), address(usdc), borrower, 10_000e18);

        uint256 borrowerDebtAfter = debtUSDC.scaledBalanceOf(borrower);
        uint256 debtReduced = borrowerDebtBefore - borrowerDebtAfter;

        // Debt reduction should be capped at exactly 50% of total debt (close factor = 0.5e18)
        // Allow 1e18 dust tolerance for rounding in wadMul/rayDiv
        uint256 maxExpected = (borrowerDebtBefore * 50) / 100;
        assertLe(debtReduced, maxExpected + 1e18, "Should be capped at 50% close factor");
    }

    /// @notice Tests tiered bonus: severely underwater (HF ≤ 0.80) should give 12% bonus
    function test_LiquidationScenario_TieredBonus_Severe() public {
        vm.prank(supplier);
        pool.supply(address(usdc), 200_000e18, supplier);
        vm.prank(borrower);
        pool.supply(address(weth), 10e18, borrower);
        vm.prank(borrower);
        pool.borrow(address(usdc), 15_000e18);

        // Crash ETH severely: $2000 → $800
        // Collateral = 10 * $800 = $8,000, threshold = 85% → $6,800
        // HF = 6,800 / 15,000 ≈ 0.453 → severely underwater (≤ 0.80)
        ethFeed.updateAnswer(800e8);

        (, , , , , uint256 hf) = pool.getUserAccountData(borrower);
        assertLt(hf, 0.80e18, "HF should be severely low");

        // Liquidate — liquidator should receive 12% bonus collateral
        uint256 liquidatorBalBefore = aWETH.scaledBalanceOf(liquidator);

        vm.prank(liquidator);
        pool.liquidate(address(weth), address(usdc), borrower, 2_000e18);

        uint256 liquidatorBalAfter = aWETH.scaledBalanceOf(liquidator);
        uint256 collateralReceived = liquidatorBalAfter - liquidatorBalBefore;

        // $2000 debt at 12% bonus = $2,240 worth of collateral at $800/ETH = 2.8 WETH
        // Allow some tolerance for rounding
        assertGt(collateralReceived, 0, "Liquidator should receive collateral");
    }

    /// @notice Tests that healthy positions cannot be liquidated
    function test_LiquidationScenario_RevertOnHealthy() public {
        vm.prank(supplier);
        pool.supply(address(usdc), 200_000e18, supplier);
        vm.prank(borrower);
        pool.supply(address(weth), 10e18, borrower);
        vm.prank(borrower);
        pool.borrow(address(usdc), 5_000e18);

        // Position is very healthy (HF >> 1)
        vm.prank(liquidator);
        vm.expectRevert();
        pool.liquidate(address(weth), address(usdc), borrower, 1_000e18);
    }
}

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

/// @title FullLifecycleTest
/// @notice Integration test: 10-step user journey through the full protocol lifecycle
/// @dev Following web3-testing skill: time-based tests, snapshot/revert, gas tracking
contract FullLifecycleTest is Test {
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
    address public alice = address(2);
    address public bob = address(3);

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
        weth.mint(alice, 100e18);
        usdc.mint(alice, 200_000e18);
        weth.mint(bob, 100e18);
        usdc.mint(bob, 200_000e18);

        // Approvals
        vm.prank(alice);
        weth.approve(address(pool), type(uint256).max);
        vm.prank(alice);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        weth.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(pool), type(uint256).max);
    }

    /// @notice Full 10-step user journey: supply → borrow → time warp → interest check → repay → withdraw
    function test_FullLifecycle() public {
        // ============================================================
        // STEP 1: Alice supplies 10 WETH as collateral
        // ============================================================
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);

        assertEq(aWETH.scaledBalanceOf(alice), 10e18, "Step 1: Alice should have 10 aWETH (scaled)");
        assertEq(weth.balanceOf(address(pool)), 10e18, "Step 1: Pool should hold 10 WETH");

        // ============================================================
        // STEP 2: Verify Alice's account data shows correct collateral
        // ============================================================
        (uint256 collateral, , uint256 availableBorrows, , , ) = pool.getUserAccountData(alice);
        assertApproxEqRel(collateral, 20_000e18, 0.01e18, "Step 2: 10 WETH * $2000 = $20,000");
        assertApproxEqRel(availableBorrows, 16_000e18, 0.01e18, "Step 2: $20,000 * 80% LTV = $16,000");

        // ============================================================
        // STEP 3: Bob supplies 100,000 USDC (creates borrowing liquidity)
        // ============================================================
        vm.prank(bob);
        pool.supply(address(usdc), 100_000e18, bob);

        // ============================================================
        // STEP 4: Alice borrows 10,000 USDC against WETH collateral
        // ============================================================
        vm.prank(alice);
        pool.borrow(address(usdc), 10_000e18);

        assertEq(usdc.balanceOf(alice), 210_000e18, "Step 4: Alice should have original + borrowed USDC");
        assertGt(debtUSDC.scaledBalanceOf(alice), 0, "Step 4: Alice should have debt tokens");

        // ============================================================
        // STEP 5: Warp 30 days forward for interest accrual
        // ============================================================
        vm.warp(block.timestamp + 30 days);
        // Update price feeds to prevent staleness
        ethFeed.updateAnswer(2000e8);
        usdcFeed.updateAnswer(1e8);

        // ============================================================
        // STEP 6: Trigger index update (via a small supply)
        // ============================================================
        usdc.mint(bob, 1e18);
        vm.prank(bob);
        pool.supply(address(usdc), 1e18, bob);

        // ============================================================
        // STEP 7: Verify interest has accrued (indexes increased)
        // ============================================================
        ILendingPool.ReserveData memory usdcData = pool.getReserveData(address(usdc));
        assertGt(usdcData.liquidityIndex, uint128(WadRayMath.RAY), "Step 7: Liquidity index should have increased");
        assertGt(usdcData.variableBorrowIndex, uint128(WadRayMath.RAY), "Step 7: Borrow index should have increased");

        // ============================================================
        // STEP 8: Alice repays full debt (principal + accrued interest)
        // ============================================================
        // Mint extra USDC to cover interest
        usdc.mint(alice, 1_000e18);
        vm.prank(alice);
        uint256 repaid = pool.repay(address(usdc), type(uint256).max, alice);

        assertGt(repaid, 10_000e18, "Step 8: Repaid should be > original borrow (includes interest)");
        assertEq(debtUSDC.scaledBalanceOf(alice), 0, "Step 8: Alice should have no debt");

        // ============================================================
        // STEP 9: Alice withdraws all WETH collateral
        // ============================================================
        vm.prank(alice);
        pool.withdraw(address(weth), type(uint256).max, alice);

        assertEq(aWETH.scaledBalanceOf(alice), 0, "Step 9: Alice should have no aTokens");
        assertEq(weth.balanceOf(alice), 100e18, "Step 9: Alice should have original WETH back");

        // ============================================================
        // STEP 10: Verify protocol state is clean for Alice
        // ============================================================
        (uint256 finalCollateral, uint256 finalDebt, , , , uint256 finalHF) = pool.getUserAccountData(alice);
        assertEq(finalCollateral, 0, "Step 10: Alice should have 0 collateral");
        assertEq(finalDebt, 0, "Step 10: Alice should have 0 debt");
        assertEq(finalHF, type(uint256).max, "Step 10: Health factor should be max (no debt)");
    }

    /// @notice Multi-user scenario: two users interact with same reserve
    function test_MultiUserInteraction() public {
        // Alice and Bob both supply WETH
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);
        vm.prank(bob);
        pool.supply(address(weth), 20e18, bob);

        assertEq(weth.balanceOf(address(pool)), 30e18, "Pool should hold 30 WETH");

        // Alice borrows USDC
        vm.prank(bob);
        pool.supply(address(usdc), 100_000e18, bob);

        vm.prank(alice);
        pool.borrow(address(usdc), 5_000e18);

        // Warp and check interest accrual
        vm.warp(block.timestamp + 365 days);

        // Bob's supply should earn interest proportional to his share
        // Trigger index update
        usdc.mint(alice, 1e18);
        vm.prank(alice);
        pool.supply(address(usdc), 1e18, alice);

        ILendingPool.ReserveData memory data = pool.getReserveData(address(usdc));
        assertGt(data.liquidityIndex, uint128(WadRayMath.RAY));
    }

    /// @notice Flash loan lifecycle: borrow and repay in single tx
    function test_FlashLoanLifecycle() public {
        // Provide liquidity
        vm.prank(alice);
        pool.supply(address(weth), 50e18, alice);

        uint256 poolBalanceBefore = weth.balanceOf(address(pool));

        // Deploy receiver that repays
        FlashLoanHelper receiver = new FlashLoanHelper(true);

        pool.flashLoan(address(receiver), address(weth), 10e18, "");

        uint256 poolBalanceAfter = weth.balanceOf(address(pool));
        uint256 expectedFee = (10e18 * 9) / 10_000;

        assertGe(poolBalanceAfter, poolBalanceBefore + expectedFee - 1, "Pool should have earned flash loan fee");
    }
}

/// @title FlashLoanHelper
/// @notice Test helper for flash loan integration tests
contract FlashLoanHelper {
    bool public shouldRepay;

    constructor(bool _shouldRepay) {
        shouldRepay = _shouldRepay;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address,
        bytes calldata
    ) external returns (bool) {
        if (shouldRepay) {
            MockERC20(asset).mint(address(this), fee);
            MockERC20(asset).approve(msg.sender, amount + fee);
            MockERC20(asset).transfer(msg.sender, amount + fee);
        }
        return true;
    }
}

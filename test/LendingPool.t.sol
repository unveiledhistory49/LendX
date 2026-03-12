// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {LendingPool} from "../src/core/LendingPool.sol";
import {ILendingPool} from "../src/interfaces/ILendingPool.sol";
import {PriceOracle} from "../src/oracle/PriceOracle.sol";
import {InterestRateStrategy} from "../src/interest/InterestRateStrategy.sol";
import {AToken} from "../src/tokens/AToken.sol";
import {DebtToken} from "../src/tokens/DebtToken.sol";
import {WadRayMath} from "../src/libraries/WadRayMath.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

/// @title MockFlashLoanReceiver
/// @notice Flash loan receiver that repays principal + fee
contract MockFlashLoanReceiver {
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
            // Repay principal + fee to the pool
            MockERC20(asset).mint(address(this), fee); // Mint fee to cover cost
            MockERC20(asset).approve(msg.sender, amount + fee);
            MockERC20(asset).transfer(msg.sender, amount + fee);
        }
        return true;
    }
}

/// @title LendingPoolTest
/// @notice Comprehensive test suite for the LendingPool contract
/// @dev Following web3-testing skill: fixtures, edge cases, fuzzing, access control,
///      events, reentrancy, gas optimization
contract LendingPoolTest is Test {
    using WadRayMath for uint256;

    // ============================================================
    //                     CONTRACTS
    // ============================================================

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

    // ============================================================
    //                     ACTORS
    // ============================================================

    address public admin = address(1);
    address public alice = address(2);
    address public bob = address(3);
    address public liquidator = address(4);

    // ============================================================
    //                     CONSTANTS
    // ============================================================

    uint256 public constant ETH_PRICE = 2000e18;
    uint256 public constant USDC_PRICE = 1e18;

    function setUp() public {
        // 1. Deploy tokens
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 18);

        // 2. Deploy price feeds
        ethFeed = new MockAggregatorV3(8, 2000e8);
        usdcFeed = new MockAggregatorV3(8, 1e8);

        // 3. Deploy oracle
        vm.startPrank(admin);
        oracle = new PriceOracle(admin);
        oracle.setAssetFeed(address(weth), address(ethFeed));
        oracle.setAssetFeed(address(usdc), address(usdcFeed));
        vm.stopPrank();

        // 4. Deploy interest rate strategy
        strategy = new InterestRateStrategy();

        // 5. Deploy LendingPool
        vm.prank(admin);
        pool = new LendingPool(address(oracle), admin);

        // 6. Deploy aTokens and debtTokens
        aWETH = new AToken(address(pool), address(weth), "LendX aWETH", "aWETH");
        aUSDC = new AToken(address(pool), address(usdc), "LendX aUSDC", "aUSDC");
        debtWETH = new DebtToken(address(pool), address(weth), "LendX debtWETH", "debtWETH");
        debtUSDC = new DebtToken(address(pool), address(usdc), "LendX debtUSDC", "debtUSDC");

        // 7. Add reserves
        vm.startPrank(admin);
        pool.addReserve(
            address(weth),
            address(aWETH),
            address(debtWETH),
            address(strategy),
            8000,  // 80% LTV
            8500,  // 85% liquidation threshold
            10500, // 5% liquidation bonus
            1000,  // 10% reserve factor
            true   // borrowing enabled
        );

        pool.addReserve(
            address(usdc),
            address(aUSDC),
            address(debtUSDC),
            address(strategy),
            7500,  // 75% LTV
            8000,  // 80% liquidation threshold
            10500, // 5% liquidation bonus
            1000,  // 10% reserve factor
            true   // borrowing enabled
        );
        vm.stopPrank();

        // 8. Fund test accounts
        weth.mint(alice, 100e18);
        usdc.mint(alice, 200_000e18);
        weth.mint(bob, 100e18);
        usdc.mint(bob, 200_000e18);
        weth.mint(liquidator, 100e18);
        usdc.mint(liquidator, 200_000e18);

        // 9. Approve pool for all users
        vm.prank(alice);
        weth.approve(address(pool), type(uint256).max);
        vm.prank(alice);
        usdc.approve(address(pool), type(uint256).max);

        vm.prank(bob);
        weth.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(pool), type(uint256).max);

        vm.prank(liquidator);
        weth.approve(address(pool), type(uint256).max);
        vm.prank(liquidator);
        usdc.approve(address(pool), type(uint256).max);
    }

    // ============================================================
    //                    SUPPLY TESTS
    // ============================================================

    function test_Supply_Success() public {
        vm.prank(alice);
        uint256 minted = pool.supply(address(weth), 10e18, alice);

        assertEq(minted, 10e18);
        assertEq(weth.balanceOf(address(pool)), 10e18);
        assertEq(aWETH.scaledBalanceOf(alice), 10e18); // index = 1 RAY, so scaled = amount
    }

    function test_Supply_OnBehalfOf() public {
        vm.prank(alice);
        pool.supply(address(weth), 10e18, bob);

        // Bob should have the aTokens, not Alice
        assertEq(aWETH.scaledBalanceOf(bob), 10e18);
        assertEq(aWETH.scaledBalanceOf(alice), 0);
    }

    function test_Revert_Supply_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert();
        pool.supply(address(weth), 0, alice);
    }

    function test_Revert_Supply_WhenPaused() public {
        vm.prank(admin);
        pool.pause();

        vm.prank(alice);
        vm.expectRevert();
        pool.supply(address(weth), 10e18, alice);
    }

    // ============================================================
    //                    WITHDRAW TESTS
    // ============================================================

    function test_Withdraw_Full() public {
        // Supply first
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);

        // Withdraw all
        vm.prank(alice);
        uint256 withdrawn = pool.withdraw(address(weth), type(uint256).max, alice);

        assertEq(withdrawn, 10e18);
        assertEq(weth.balanceOf(alice), 100e18); // Restored to original
        assertEq(aWETH.scaledBalanceOf(alice), 0);
    }

    function test_Withdraw_Partial() public {
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);

        vm.prank(alice);
        pool.withdraw(address(weth), 5e18, alice);

        assertEq(weth.balanceOf(alice), 95e18); // 100 - 10 + 5
        assertEq(aWETH.scaledBalanceOf(alice), 5e18);
    }

    function test_Withdraw_ToDifferentAddress() public {
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);

        vm.prank(alice);
        pool.withdraw(address(weth), 5e18, bob);

        // Bob receives the underlying
        assertGe(weth.balanceOf(bob), 100e18 + 5e18 - 1); // approx due to rounding
    }

    function test_Revert_Withdraw_InsufficientBalance() public {
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);

        vm.prank(alice);
        vm.expectRevert();
        pool.withdraw(address(weth), 20e18, alice);
    }

    // ============================================================
    //                    BORROW TESTS
    // ============================================================

    function test_Borrow_Success() public {
        // Supply WETH as collateral
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);
        // collateral = 10 * 2000 = $20,000 USD, LTV 80% → can borrow $16,000

        // Provide USDC liquidity for borrowing
        vm.prank(bob);
        pool.supply(address(usdc), 50_000e18, bob);

        // Borrow USDC against WETH collateral
        vm.prank(alice);
        pool.borrow(address(usdc), 10_000e18);

        assertEq(usdc.balanceOf(alice), 200_000e18 + 10_000e18);
        assertGt(debtUSDC.scaledBalanceOf(alice), 0);
    }

    function test_Revert_Borrow_InsufficientCollateral() public {
        vm.prank(alice);
        pool.supply(address(weth), 1e18, alice);
        // collateral = 1 * 2000 = $2,000, LTV 80% → max borrow = $1,600

        vm.prank(bob);
        pool.supply(address(usdc), 50_000e18, bob);

        // Try to borrow $5,000 — should fail
        vm.prank(alice);
        vm.expectRevert();
        pool.borrow(address(usdc), 5_000e18);
    }

    function test_Revert_Borrow_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert();
        pool.borrow(address(usdc), 0);
    }

    // ============================================================
    //                    REPAY TESTS
    // ============================================================

    function test_Repay_Full() public {
        // Setup: supply + borrow
        _setupBorrowPosition(alice, 10e18, 5_000e18);

        // Repay full debt
        vm.prank(alice);
        uint256 repaid = pool.repay(address(usdc), type(uint256).max, alice);

        assertGe(repaid, 5_000e18); // At least the borrowed amount (may include interest)
        assertEq(debtUSDC.scaledBalanceOf(alice), 0);
    }

    function test_Repay_Partial() public {
        _setupBorrowPosition(alice, 10e18, 5_000e18);

        vm.prank(alice);
        uint256 repaid = pool.repay(address(usdc), 2_000e18, alice);

        assertEq(repaid, 2_000e18);
        assertGt(debtUSDC.scaledBalanceOf(alice), 0, "Should still have debt");
    }

    function test_Repay_OnBehalfOf() public {
        _setupBorrowPosition(alice, 10e18, 5_000e18);

        // Bob repays Alice's debt
        vm.prank(bob);
        pool.repay(address(usdc), 2_000e18, alice);

        // Alice's debt reduced, Bob's USDC reduced
        assertLt(usdc.balanceOf(bob), 200_000e18);
    }

    // ============================================================
    //                  LIQUIDATION TESTS
    // ============================================================

    function test_Liquidation_Success() public {
        // Setup: Alice has a borrow position
        _setupBorrowPosition(alice, 10e18, 12_000e18);

        // Crash ETH price to make position undercollateralized
        // collateral = 10 * 1000 = $10,000, threshold 85% → healthy threshold = $8,500
        // debt = $12,000 → healthFactor < 1
        ethFeed.updateAnswer(1000e8); // ETH drops from $2000 to $1000

        // Liquidator repays some debt and seizes collateral
        vm.prank(liquidator);
        pool.liquidate(address(weth), address(usdc), alice, 3_000e18);

        // Liquidator should have received aTokens (collateral)
        assertGt(aWETH.scaledBalanceOf(liquidator), 0, "Liquidator should have received collateral");
    }

    function test_Revert_Liquidation_HealthyPosition() public {
        _setupBorrowPosition(alice, 10e18, 5_000e18);

        // Position is healthy → liquidation should fail
        vm.prank(liquidator);
        vm.expectRevert();
        pool.liquidate(address(weth), address(usdc), alice, 1_000e18);
    }

    function test_Revert_Liquidation_SelfLiquidation() public {
        _setupBorrowPosition(alice, 10e18, 12_000e18);
        ethFeed.updateAnswer(1000e8);

        vm.prank(alice);
        vm.expectRevert();
        pool.liquidate(address(weth), address(usdc), alice, 1_000e18);
    }

    // ============================================================
    //                  FLASH LOAN TESTS
    // ============================================================

    function test_FlashLoan_Success() public {
        // Provide liquidity
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);

        // Deploy a receiver that repays
        MockFlashLoanReceiver receiver = new MockFlashLoanReceiver(true);

        vm.prank(bob);
        pool.flashLoan(address(receiver), address(weth), 5e18, "");

        // Pool should have received the fee
        uint256 expectedFee = (5e18 * 9) / 10_000; // 0.09%
        assertGe(weth.balanceOf(address(pool)), 10e18 + expectedFee - 1); // -1 for rounding
    }

    function test_Revert_FlashLoan_NotRepaid() public {
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);

        MockFlashLoanReceiver badReceiver = new MockFlashLoanReceiver(false);

        vm.prank(bob);
        vm.expectRevert(LendingPool.FlashLoan__NotRepaid.selector);
        pool.flashLoan(address(badReceiver), address(weth), 5e18, "");
    }

    function test_FlashLoan_EmitsEvent() public {
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);

        MockFlashLoanReceiver receiver = new MockFlashLoanReceiver(true);
        uint256 fee = (5e18 * 9) / 10_000;

        vm.expectEmit(true, true, false, true);
        emit ILendingPool.FlashLoan(address(receiver), address(weth), 5e18, fee);

        vm.prank(bob);
        pool.flashLoan(address(receiver), address(weth), 5e18, "");
    }

    // ============================================================
    //                  ADMIN / ACCESS CONTROL
    // ============================================================

    function test_AddReserve_EmitsEvent() public {
        MockERC20 newToken = new MockERC20("DAI", "DAI", 18);
        AToken aDAI = new AToken(address(pool), address(newToken), "LendX aDAI", "aDAI");
        DebtToken debtDAI = new DebtToken(address(pool), address(newToken), "LendX debtDAI", "debtDAI");

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit LendingPool.ReserveAdded(address(newToken), address(aDAI), address(debtDAI), address(strategy));
        pool.addReserve(
            address(newToken), address(aDAI), address(debtDAI), address(strategy),
            7500, 8000, 10500, 1000, true
        );
    }

    function test_Revert_AddReserve_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        pool.addReserve(
            address(0xDEAD), address(aWETH), address(debtWETH), address(strategy),
            8000, 8500, 10500, 1000, true
        );
    }

    function test_Revert_AddReserve_DuplicateAsset() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(LendingPool.LendingPool__ReserveAlreadyExists.selector, address(weth)));
        pool.addReserve(
            address(weth), address(aWETH), address(debtWETH), address(strategy),
            8000, 8500, 10500, 1000, true
        );
    }

    function test_Revert_AddReserve_WrongTokenConfig() public {
        // Create aToken for wrong underlying
        MockERC20 wrongToken = new MockERC20("Wrong", "WRG", 18);
        AToken wrongAToken = new AToken(address(pool), address(wrongToken), "wrong", "wrg");
        DebtToken wrongDebt = new DebtToken(address(pool), address(wrongToken), "wrong", "wrg");

        MockERC20 dai = new MockERC20("DAI", "DAI", 18);

        vm.prank(admin);
        vm.expectRevert();
        pool.addReserve(
            address(dai), address(wrongAToken), address(wrongDebt), address(strategy),
            7500, 8000, 10500, 1000, true
        );
    }

    function test_Pause_BlocksSupply() public {
        vm.prank(admin);
        pool.pause();

        vm.prank(alice);
        vm.expectRevert();
        pool.supply(address(weth), 1e18, alice);
    }

    function test_Unpause_AllowsSupply() public {
        vm.prank(admin);
        pool.pause();

        vm.prank(admin);
        pool.unpause();

        vm.prank(alice);
        pool.supply(address(weth), 1e18, alice);
    }

    function test_SetReserveFrozen() public {
        vm.prank(admin);
        pool.setReserveFrozen(address(weth), true);

        ILendingPool.ReserveData memory data = pool.getReserveData(address(weth));
        assertTrue(data.frozen);
    }

    // ============================================================
    //                    VIEW FUNCTIONS
    // ============================================================

    function test_GetUserAccountData_NoPosition() public view {
        (uint256 collateral, uint256 debt, uint256 borrows, , , uint256 hf) =
            pool.getUserAccountData(alice);

        assertEq(collateral, 0);
        assertEq(debt, 0);
        assertEq(borrows, 0);
        assertEq(hf, type(uint256).max); // No debt = infinite health factor
    }

    function test_GetUserAccountData_WithPosition() public {
        vm.prank(alice);
        pool.supply(address(weth), 10e18, alice);

        (uint256 collateral, , uint256 availableBorrows, , , ) =
            pool.getUserAccountData(alice);

        // 10 WETH * $2000 = $20,000 collateral
        assertApproxEqRel(collateral, 20_000e18, 0.01e18);
        // Available borrows = $20,000 * 80% LTV = $16,000
        assertApproxEqRel(availableBorrows, 16_000e18, 0.01e18);
    }

    function test_GetReserveData() public view {
        ILendingPool.ReserveData memory data = pool.getReserveData(address(weth));

        assertEq(data.aTokenAddress, address(aWETH));
        assertEq(data.debtTokenAddress, address(debtWETH));
        assertTrue(data.active);
        assertTrue(data.borrowingEnabled);
        assertFalse(data.frozen);
    }

    function test_GetAssetPrice() public view {
        assertEq(pool.getAssetPrice(address(weth)), 2000e18);
        assertEq(pool.getAssetPrice(address(usdc)), 1e18);
    }

    function test_GetReservesList() public view {
        address[] memory reserves = pool.getReservesList();
        assertEq(reserves.length, 2);
        assertEq(reserves[0], address(weth));
        assertEq(reserves[1], address(usdc));
    }

    // ============================================================
    //              INTEREST ACCRUAL TESTS
    // ============================================================

    function test_InterestAccrual_SupplyAndBorrow() public {
        _setupBorrowPosition(alice, 10e18, 5_000e18);

        // Warp time forward 1 year
        vm.warp(block.timestamp + 365 days);

        // Trigger index update by supplying a tiny amount
        vm.prank(bob);
        pool.supply(address(usdc), 1e18, bob);

        // Check reserve indexes have increased
        ILendingPool.ReserveData memory data = pool.getReserveData(address(usdc));
        assertGt(data.liquidityIndex, uint128(WadRayMath.RAY), "Liquidity index should have increased");
        assertGt(data.variableBorrowIndex, uint128(WadRayMath.RAY), "Borrow index should have increased");
    }

    // ============================================================
    //                  HEALTH FACTOR TESTS
    // ============================================================

    function test_Revert_Withdraw_BreaksHealthFactor() public {
        _setupBorrowPosition(alice, 10e18, 12_000e18);

        // Try withdrawing most collateral → health factor breaks
        vm.prank(alice);
        vm.expectRevert();
        pool.withdraw(address(weth), 9e18, alice);
    }

    // ============================================================
    //                    FUZZING TESTS
    // ============================================================

    function testFuzz_Supply_ValidAmounts(uint128 amount) public {
        vm.assume(amount > 0 && amount <= 100e18);

        weth.mint(alice, amount);
        vm.prank(alice);
        uint256 minted = pool.supply(address(weth), amount, alice);

        assertEq(minted, amount);
    }

    // ============================================================
    //                  HELPER FUNCTIONS
    // ============================================================

    /// @dev Sets up a borrow position: supply WETH, then borrow USDC
    function _setupBorrowPosition(
        address user,
        uint256 supplyAmount,
        uint256 borrowAmount
    ) internal {
        // Supply WETH as collateral
        vm.prank(user);
        pool.supply(address(weth), supplyAmount, user);

        // Provide USDC liquidity (from bob)
        vm.prank(bob);
        pool.supply(address(usdc), 100_000e18, bob);

        // Borrow USDC
        vm.prank(user);
        pool.borrow(address(usdc), borrowAmount);
    }
}

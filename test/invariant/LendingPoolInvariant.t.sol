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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockAggregatorV3} from "../mocks/MockAggregatorV3.sol";

/// @title LendingPoolHandler
/// @notice Handler contract for invariant testing — performs random supply/borrow/repay/withdraw actions
/// @dev Following web3-testing skill: invariant testing with handler contracts
contract LendingPoolHandler is Test {
    using WadRayMath for uint256;

    LendingPool public pool;
    MockERC20 public weth;
    MockERC20 public usdc;

    address[] public actors;
    uint256 public constant NUM_ACTORS = 3;

    // Ghost variables to track expected state
    uint256 public ghost_totalSuppliedWETH;
    uint256 public ghost_totalSuppliedUSDC;
    uint256 public ghost_totalBorrowedUSDC;
    uint256 public ghost_totalRepaidUSDC;
    uint256 public ghost_supplyCalls;
    uint256 public ghost_borrowCalls;
    uint256 public ghost_repayCalls;
    uint256 public ghost_withdrawCalls;

    constructor(LendingPool _pool, MockERC20 _weth, MockERC20 _usdc) {
        pool = _pool;
        weth = _weth;
        usdc = _usdc;

        // Create actors
        for (uint256 i = 0; i < NUM_ACTORS; i++) {
            address actor = address(uint160(100 + i));
            actors.push(actor);

            // Fund actors
            weth.mint(actor, 1000e18);
            usdc.mint(actor, 1_000_000e18);

            // Approve
            vm.prank(actor);
            weth.approve(address(pool), type(uint256).max);
            vm.prank(actor);
            usdc.approve(address(pool), type(uint256).max);
        }
    }

    function _getActor(uint256 seed) internal view returns (address) {
        return actors[seed % NUM_ACTORS];
    }

    /// @notice Supply WETH with bounded amount
    function supplyWETH(uint256 actorSeed, uint256 amount) external {
        address actor = _getActor(actorSeed);
        amount = bound(amount, 1e18, 50e18);

        uint256 balance = weth.balanceOf(actor);
        if (balance < amount) return; // Skip if insufficient

        vm.prank(actor);
        try pool.supply(address(weth), amount, actor) {
            ghost_totalSuppliedWETH += amount;
            ghost_supplyCalls++;
        } catch {}
    }

    /// @notice Supply USDC with bounded amount
    function supplyUSDC(uint256 actorSeed, uint256 amount) external {
        address actor = _getActor(actorSeed);
        amount = bound(amount, 100e18, 100_000e18);

        uint256 balance = usdc.balanceOf(actor);
        if (balance < amount) return;

        vm.prank(actor);
        try pool.supply(address(usdc), amount, actor) {
            ghost_totalSuppliedUSDC += amount;
            ghost_supplyCalls++;
        } catch {}
    }

    /// @notice Borrow USDC with bounded amount
    function borrowUSDC(uint256 actorSeed, uint256 amount) external {
        address actor = _getActor(actorSeed);
        amount = bound(amount, 100e18, 5_000e18);

        vm.prank(actor);
        try pool.borrow(address(usdc), amount) {
            ghost_totalBorrowedUSDC += amount;
            ghost_borrowCalls++;
        } catch {}
    }

    /// @notice Repay USDC debt
    function repayUSDC(uint256 actorSeed, uint256 amount) external {
        address actor = _getActor(actorSeed);
        amount = bound(amount, 100e18, 10_000e18);

        vm.prank(actor);
        try pool.repay(address(usdc), amount, actor) returns (uint256 actualRepaid) {
            ghost_totalRepaidUSDC += actualRepaid;
            ghost_repayCalls++;
        } catch {}
    }

    /// @notice Withdraw WETH
    function withdrawWETH(uint256 actorSeed, uint256 amount) external {
        address actor = _getActor(actorSeed);
        amount = bound(amount, 0.1e18, 10e18);

        vm.prank(actor);
        try pool.withdraw(address(weth), amount, actor) {
            ghost_withdrawCalls++;
        } catch {}
    }

    /// @notice Advance time to accrue interest
    function warpTime(uint256 seconds_) external {
        seconds_ = bound(seconds_, 1 hours, 30 days);
        vm.warp(block.timestamp + seconds_);
    }
}

/// @title LendingPoolInvariantTest
/// @notice Invariant tests for the LendingPool
/// @dev Tests protocol solvency, aToken supply consistency, and debt-collateral relationship
contract LendingPoolInvariantTest is Test {
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

    LendingPoolHandler public handler;

    address public admin = address(1);

    function setUp() public {
        vm.warp(100_000);

        // Deploy
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 18);
        ethFeed = new MockAggregatorV3(8, 2000e8);
        usdcFeed = new MockAggregatorV3(8, 1e8);

        vm.startPrank(admin);
        oracle = new PriceOracle(admin);
        oracle.setAssetFeed(address(weth), address(ethFeed));
        oracle.setAssetFeed(address(usdc), address(usdcFeed));
        vm.stopPrank();

        strategy = new InterestRateStrategy();
        vm.prank(admin);
        pool = new LendingPool(address(oracle), admin);

        aWETH = new AToken(address(pool), address(weth), "aWETH", "aWETH");
        aUSDC = new AToken(address(pool), address(usdc), "aUSDC", "aUSDC");
        debtWETH = new DebtToken(address(pool), address(weth), "debtWETH", "debtWETH");
        debtUSDC = new DebtToken(address(pool), address(usdc), "debtUSDC", "debtUSDC");

        vm.startPrank(admin);
        pool.addReserve(address(weth), address(aWETH), address(debtWETH), address(strategy), 8000, 8500, 10500, 1000, true);
        pool.addReserve(address(usdc), address(aUSDC), address(debtUSDC), address(strategy), 7500, 8000, 10500, 1000, true);
        vm.stopPrank();

        // Deploy handler
        handler = new LendingPoolHandler(pool, weth, usdc);

        // Target handler for invariant testing
        targetContract(address(handler));
    }

    /// @notice INVARIANT 1: Protocol solvency — pool balance covers deposits minus borrows
    function invariant_ProtocolSolvency_WETH() public view {
        ILendingPool.ReserveData memory reserve = pool.getReserveData(address(weth));
        uint256 poolBalance = weth.balanceOf(address(pool));
        uint256 totalBorrows = debtWETH.totalSupplyWithIndex(reserve.variableBorrowIndex);
        uint256 totalObligations = aWETH.totalSupplyWithIndex(reserve.liquidityIndex);
        assertGe(poolBalance + totalBorrows, totalObligations - 1e9, "WETH: pool insolvent");
    }

    /// @notice INVARIANT 2: aToken supply consistency — scaled supply matches pool accounting
    function invariant_ATokenSupplyConsistency() public view {
        ILendingPool.ReserveData memory reserve = pool.getReserveData(address(usdc));
        uint256 poolBalance = usdc.balanceOf(address(pool));
        uint256 totalBorrows = debtUSDC.totalSupplyWithIndex(reserve.variableBorrowIndex);
        uint256 aTokenObligations = aUSDC.totalSupplyWithIndex(reserve.liquidityIndex);
        // poolBalance + totalBorrows should approximately equal total aToken obligations
        assertGe(poolBalance + totalBorrows + 1e9, aTokenObligations, "USDC: aToken supply mismatch");
    }

    /// @notice INVARIANT 3: Borrows require prior supply
    function invariant_SupplyBeforeBorrow() public view {
        if (handler.ghost_borrowCalls() > 0) {
            assertGt(handler.ghost_supplyCalls(), 0, "Must supply before borrowing");
        }
    }

    /// @notice INVARIANT 4: Total borrows can never exceed total deposits (ghost tracking)
    function invariant_SupplyGreaterThanBorrow() public view {
        assertGe(
            handler.ghost_totalSuppliedUSDC(),
            handler.ghost_totalBorrowedUSDC(),
            "Borrows exceed deposits"
        );
    }

    /// @notice Shows summary after invariant run
    function invariant_callSummary() public view {
        console.log("--- Call Summary ---");
        console.log("Supply calls:", handler.ghost_supplyCalls());
        console.log("Borrow calls:", handler.ghost_borrowCalls());
        console.log("Repay calls:", handler.ghost_repayCalls());
        console.log("Withdraw calls:", handler.ghost_withdrawCalls());
        console.log("Total WETH supplied:", handler.ghost_totalSuppliedWETH());
        console.log("Total USDC supplied:", handler.ghost_totalSuppliedUSDC());
        console.log("Total USDC borrowed:", handler.ghost_totalBorrowedUSDC());
        console.log("Total USDC repaid:", handler.ghost_totalRepaidUSDC());
    }
}

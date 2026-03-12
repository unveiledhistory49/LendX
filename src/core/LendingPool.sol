// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {IFlashLoanReceiver} from "../interfaces/IFlashLoanReceiver.sol";
import {IInterestRateStrategy} from "../interfaces/IInterestRateStrategy.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

import {AToken} from "../tokens/AToken.sol";
import {DebtToken} from "../tokens/DebtToken.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";
import {ValidationLogic} from "../logic/ValidationLogic.sol";
import {SupplyLogic} from "../logic/SupplyLogic.sol";
import {BorrowLogic} from "../logic/BorrowLogic.sol";
import {LiquidationLogic} from "../logic/LiquidationLogic.sol";

/// @title LendingPool
/// @author LendX Protocol
/// @notice Main entry point for the LendX lending and borrowing protocol
/// @dev All user interactions route through this contract. Each core operation delegates
///      to a separate logic library (SupplyLogic, BorrowLogic, LiquidationLogic).
///      Follows Checks-Effects-Interactions pattern and uses ReentrancyGuard on all
///      state-changing functions. Includes Pausable circuit breaker for emergency response.
contract LendingPool is ILendingPool, Ownable2Step, ReentrancyGuard, Pausable {
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    // ============================================================
    //                       ERRORS
    // ============================================================

    error LendingPool__AssetNotSupported(address asset);
    error LendingPool__AssetNotActive(address asset);
    error LendingPool__InvalidAmount();
    error LendingPool__HealthFactorTooLow(uint256 healthFactor);
    error LendingPool__InsufficientCollateral(uint256 required, uint256 available);
    error LendingPool__ReserveAlreadyExists(address asset);
    error LendingPool__InvalidTokenConfig(address asset, address expectedUnderlying, address actualUnderlying);
    error FlashLoan__ExecutionFailed();
    error FlashLoan__NotRepaid();

    // ============================================================
    //                       EVENTS
    // ============================================================

    /// @notice Emitted when a new reserve is added
    event ReserveAdded(address indexed asset, address aToken, address debtToken, address strategy);

    /// @notice Emitted when reserve frozen status changes
    event ReserveFrozenChanged(address indexed asset, bool frozen);

    /// @notice Emitted when reserve borrowing status changes
    event BorrowingEnabledChanged(address indexed asset, bool enabled);

    // ============================================================
    //                      CONSTANTS
    // ============================================================

    /// @notice Flash loan fee: 0.09% (9 basis points)
    uint256 public constant FLASH_LOAN_FEE = 9;

    // ============================================================
    //                       STATE
    // ============================================================

    /// @notice The price oracle contract
    IPriceOracle public immutable oracle;

    /// @notice Mapping of asset address to its reserve data
    mapping(address => ReserveData) internal _reserves;

    /// @notice List of all reserve asset addresses
    address[] internal _reservesList;

    /// @notice Tracks which assets each user has supplied
    mapping(address => mapping(address => bool)) internal _userSuppliedAssets;

    /// @notice Tracks which assets each user has borrowed
    mapping(address => mapping(address => bool)) internal _userBorrowedAssets;

    // ============================================================
    //                    CONSTRUCTOR
    // ============================================================

    /// @notice Initializes the LendingPool with oracle and admin
    /// @param _oracle The price oracle contract address
    /// @param owner The admin address (uses Ownable2Step for secure transfer)
    constructor(address _oracle, address owner) Ownable(owner) {
        oracle = IPriceOracle(_oracle);
    }

    // ============================================================
    //                  ADMIN FUNCTIONS
    // ============================================================

    /// @notice Pauses all user-facing protocol actions
    /// @dev Only callable by protocol owner. Use in emergencies (oracle attacks, critical bugs).
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses all user-facing protocol actions
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Adds a new reserve to the protocol
    /// @dev Only callable by contract owner. Initializes indexes to 1 RAY.
    ///      Validates that aToken and debtToken are configured for the correct underlying asset.
    ///      Reverts if a reserve already exists for this asset (C-5 fix).
    /// @param asset The underlying asset address
    /// @param aTokenAddress The aToken contract for this asset
    /// @param debtTokenAddress The debt token contract for this asset
    /// @param interestRateStrategy The interest rate strategy contract
    /// @param ltv Loan-to-value ratio (basis points)
    /// @param liquidationThreshold Liquidation threshold (basis points)
    /// @param liquidationBonus Liquidation bonus (basis points, 10500 = 5%)
    /// @param reserveFactor Protocol fee on interest (basis points)
    /// @param borrowingEnabled Whether borrowing is enabled for this asset
    function addReserve(
        address asset,
        address aTokenAddress,
        address debtTokenAddress,
        address interestRateStrategy,
        uint16 ltv,
        uint16 liquidationThreshold,
        uint16 liquidationBonus,
        uint16 reserveFactor,
        bool borrowingEnabled
    ) external onlyOwner {
        // C-5: Prevent overwriting existing reserves
        if (_reserves[asset].aTokenAddress != address(0)) {
            revert LendingPool__ReserveAlreadyExists(asset);
        }

        // M-7: Validate that token contracts match the asset
        address aTokenUnderlying = AToken(aTokenAddress).UNDERLYING_ASSET_ADDRESS();
        if (aTokenUnderlying != asset) {
            revert LendingPool__InvalidTokenConfig(asset, asset, aTokenUnderlying);
        }

        address debtTokenUnderlying = DebtToken(debtTokenAddress).UNDERLYING_ASSET_ADDRESS();
        if (debtTokenUnderlying != asset) {
            revert LendingPool__InvalidTokenConfig(asset, asset, debtTokenUnderlying);
        }

        _reserves[asset] = ReserveData({
            liquidityIndex: uint128(WadRayMath.RAY),
            variableBorrowIndex: uint128(WadRayMath.RAY),
            currentLiquidityRate: 0,
            currentVariableBorrowRate: 0,
            lastUpdateTimestamp: uint40(block.timestamp),
            ltv: ltv,
            liquidationThreshold: liquidationThreshold,
            liquidationBonus: liquidationBonus,
            reserveFactor: reserveFactor,
            active: true,
            frozen: false,
            borrowingEnabled: borrowingEnabled,
            aTokenAddress: aTokenAddress,
            debtTokenAddress: debtTokenAddress,
            interestRateStrategy: interestRateStrategy
        });

        _reservesList.push(asset);

        // I-5: Emit event for on-chain monitoring
        emit ReserveAdded(asset, aTokenAddress, debtTokenAddress, interestRateStrategy);
    }

    /// @notice Freezes or unfreezes a reserve
    function setReserveFrozen(address asset, bool frozen) external onlyOwner {
        _reserves[asset].frozen = frozen;
        emit ReserveFrozenChanged(asset, frozen);
    }

    /// @notice Enables or disables borrowing
    function setBorrowingEnabled(address asset, bool enabled) external onlyOwner {
        _reserves[asset].borrowingEnabled = enabled;
        emit BorrowingEnabledChanged(asset, enabled);
    }

    // ============================================================
    //                   USER FUNCTIONS
    // ============================================================

    /// @notice Supplies an amount of underlying asset into the reserve
    /// @dev Mints a corresponding amount of aTokens scaled by the liquidity index
    /// @param asset The address of the underlying ERC-20 token
    /// @param amount The amount to supply (in token decimals)
    /// @param onBehalfOf The address that will receive the aTokens
    /// @return The amount of aTokens minted
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override nonReentrant whenNotPaused returns (uint256) {
        ReserveData storage reserve = _reserves[asset];

        // CHECKS
        ValidationLogic.validateSupply(reserve, amount, asset);

        // Update indexes before operation
        _updateIndexes(asset);

        // EFFECTS + INTERACTIONS (delegated to SupplyLogic)
        SupplyLogic.executeSupply(
            reserve,
            asset,
            amount,
            onBehalfOf,
            _userSuppliedAssets[onBehalfOf]
        );

        // Update interest rates based on new liquidity
        _updateInterestRates(asset);

        return amount;
    }

    /// @notice Withdraws an amount of underlying asset from the reserve
    /// @dev Burns aTokens and transfers underlying to the recipient
    /// @param asset The address of the underlying ERC-20 token
    /// @param amount The amount to withdraw (use type(uint256).max for full withdrawal)
    /// @param to The address that will receive the underlying tokens
    /// @return The final amount withdrawn
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external override nonReentrant whenNotPaused returns (uint256) {
        ReserveData storage reserve = _reserves[asset];

        // Calculate actual balance
        AToken aToken = AToken(reserve.aTokenAddress);
        uint256 userBalance = aToken.balanceOfWithIndex(msg.sender, reserve.liquidityIndex);

        if (amount == type(uint256).max) {
            amount = userBalance;
        }

        // CHECKS
        ValidationLogic.validateWithdraw(reserve, amount, userBalance, asset);

        // Update indexes before operation
        _updateIndexes(asset);

        // EFFECTS + INTERACTIONS
        uint256 withdrawn = SupplyLogic.executeWithdraw(
            reserve,
            asset,
            amount,
            to,
            _userSuppliedAssets[msg.sender]
        );

        // Validate health factor after withdrawal
        (, , , , , uint256 healthFactor) = _getUserAccountData(msg.sender);
        if (_hasDebt(msg.sender) && healthFactor < 1e18) {
            revert LendingPool__HealthFactorTooLow(healthFactor);
        }

        // Update interest rates
        _updateInterestRates(asset);

        return withdrawn;
    }

    /// @notice Borrows an amount of asset against deposited collateral
    /// @dev Mints debt tokens and transfers the underlying to the borrower
    /// @param asset The address of the underlying ERC-20 token to borrow
    /// @param amount The amount to borrow (in token decimals)
    function borrow(
        address asset,
        uint256 amount
    ) external override nonReentrant whenNotPaused {
        ReserveData storage reserve = _reserves[asset];

        // Update indexes before operation
        _updateIndexes(asset);

        // Calculate user's position BEFORE borrow to get LTV
        (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,
            ,
            ,
            uint256 ltv,
        ) = _getUserAccountData(msg.sender);

        // Calculate new debt after this borrow
        uint256 borrowAmountUSD = amount.wadMul(oracle.getAssetPrice(asset));
        uint256 newTotalDebtUSD = totalDebtUSD + borrowAmountUSD;

        // CHECKS
        ValidationLogic.validateBorrow(
            reserve,
            amount,
            totalCollateralUSD,
            newTotalDebtUSD,
            ltv,
            asset
        );

        // EFFECTS + INTERACTIONS
        BorrowLogic.executeBorrow(
            reserve,
            asset,
            amount,
            msg.sender,
            _userBorrowedAssets[msg.sender]
        );

        // Update interest rates
        _updateInterestRates(asset);
    }

    /// @notice Repays a borrowed amount on behalf of a user
    /// @dev Burns debt tokens and transfers underlying from the payer to the pool
    /// @param asset The address of the borrowed ERC-20 token
    /// @param amount The amount to repay (use type(uint256).max for full repayment)
    /// @param onBehalfOf The address of the user whose debt is being repaid
    /// @return The final amount repaid
    function repay(
        address asset,
        uint256 amount,
        address onBehalfOf
    ) external override nonReentrant whenNotPaused returns (uint256) {
        ReserveData storage reserve = _reserves[asset];

        // Calculate current debt
        DebtToken debtToken = DebtToken(reserve.debtTokenAddress);
        uint256 currentDebt = debtToken.balanceOfWithIndex(onBehalfOf, reserve.variableBorrowIndex);

        // CHECKS
        ValidationLogic.validateRepay(reserve, amount, currentDebt, asset);

        // Update indexes before operation
        _updateIndexes(asset);

        // EFFECTS + INTERACTIONS
        uint256 actualRepaid = BorrowLogic.executeRepay(
            reserve,
            asset,
            amount,
            onBehalfOf,
            _userBorrowedAssets[onBehalfOf]
        );

        // Update interest rates
        _updateInterestRates(asset);

        return actualRepaid;
    }

    /// @notice Liquidates an undercollateralized position
    /// @dev Validates the position is underwater, caps at close factor, applies tiered bonus
    /// @param collateralAsset The address of the collateral asset to seize
    /// @param debtAsset The address of the debt asset to repay
    /// @param borrower The address of the borrower being liquidated
    /// @param debtToCover The amount of debt to cover (in debt asset decimals)
    function liquidate(
        address collateralAsset,
        address debtAsset,
        address borrower,
        uint256 debtToCover
    ) external override nonReentrant whenNotPaused {
        ReserveData storage collateralReserve = _reserves[collateralAsset];
        ReserveData storage debtReserve = _reserves[debtAsset];

        // Update indexes
        _updateIndexes(collateralAsset);
        _updateIndexes(debtAsset);

        // Get borrower's health factor
        (, , , , , uint256 healthFactor) = _getUserAccountData(borrower);

        // CHECKS (now with actual asset addresses in errors)
        ValidationLogic.validateLiquidation(
            collateralReserve,
            debtReserve,
            healthFactor,
            debtToCover,
            msg.sender,
            borrower,
            collateralAsset,
            debtAsset
        );

        // EFFECTS + INTERACTIONS
        LiquidationLogic.executeLiquidation(
            collateralReserve,
            debtReserve,
            LiquidationLogic.LiquidationParams({
                collateralAsset: collateralAsset,
                debtAsset: debtAsset,
                borrower: borrower,
                debtToCover: debtToCover,
                healthFactor: healthFactor,
                oracle: address(oracle)
            })
        );

        // Update interest rates for both assets
        _updateInterestRates(collateralAsset);
        _updateInterestRates(debtAsset);
    }

    /// @notice Executes a flash loan — borrow and repay within a single transaction
    /// @dev The receiver must implement IFlashLoanReceiver and return true.
    ///      Fee: 0.09% (9 basis points). Must repay amount + fee.
    /// @param receiverAddress The address of the contract receiving the flash loan
    /// @param asset The address of the asset to flash borrow
    /// @param amount The amount to flash borrow
    /// @param params Arbitrary bytes to pass to the receiver's executeOperation
    function flashLoan(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params
    ) external override nonReentrant whenNotPaused {
        ReserveData storage reserve = _reserves[asset];
        if (!reserve.active) revert LendingPool__AssetNotActive(asset);

        uint256 fee = (amount * FLASH_LOAN_FEE) / 10_000;
        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));

        // Transfer asset to receiver
        IERC20(asset).safeTransfer(receiverAddress, amount);

        // Call receiver's execute operation
        bool success = IFlashLoanReceiver(receiverAddress).executeOperation(
            asset,
            amount,
            fee,
            msg.sender,
            params
        );
        if (!success) revert FlashLoan__ExecutionFailed();

        // Verify repayment (balance must increase by at least the fee)
        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));
        if (balanceAfter < balanceBefore + fee) revert FlashLoan__NotRepaid();

        emit FlashLoan(receiverAddress, asset, amount, fee);
    }

    // ============================================================
    //                    VIEW FUNCTIONS
    // ============================================================

    /// @notice Returns the full account data for a user across all reserves
    /// @param user The address of the user
    /// @return totalCollateralUSD Total collateral in USD (WAD)
    /// @return totalDebtUSD Total debt in USD (WAD)
    /// @return availableBorrowsUSD Available borrowing power in USD (WAD)
    /// @return currentLiquidationThreshold Weighted average liquidation threshold (basis points)
    /// @return ltv Weighted average LTV (basis points)
    /// @return healthFactor Health factor (WAD), < 1e18 means liquidatable
    function getUserAccountData(address user)
        external
        view
        override
        returns (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,
            uint256 availableBorrowsUSD,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return _getUserAccountData(user);
    }

    /// @notice Returns the reserve data for a given asset
    /// @param asset The address of the underlying asset
    /// @return The ReserveData struct
    function getReserveData(address asset) external view override returns (ReserveData memory) {
        return _reserves[asset];
    }

    /// @notice Returns the USD price of an asset from the oracle
    /// @param asset The address of the asset
    /// @return The price in WAD (18 decimals)
    function getAssetPrice(address asset) external view override returns (uint256) {
        return oracle.getAssetPrice(asset);
    }

    /// @notice Returns the list of all reserve asset addresses
    /// @return The array of reserve addresses
    function getReservesList() external view returns (address[] memory) {
        return _reservesList;
    }

    // ============================================================
    //                  INTERNAL FUNCTIONS
    // ============================================================

    /// @notice Internal implementation of getUserAccountData
    /// @dev Split into helper functions to avoid stack-too-deep errors
    function _getUserAccountData(address user)
        internal
        view
        returns (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,
            uint256 availableBorrowsUSD,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        uint256 weightedThreshold;
        uint256 weightedLtv;

        (totalCollateralUSD, totalDebtUSD, weightedThreshold, weightedLtv) =
            _calculateUserPositions(user);

        // Calculate weighted averages
        if (totalCollateralUSD > 0) {
            currentLiquidationThreshold = weightedThreshold / totalCollateralUSD;
            ltv = weightedLtv / totalCollateralUSD;
        }

        // Calculate available borrows
        if (totalCollateralUSD > 0 && ltv > 0) {
            uint256 maxBorrowUSD = (totalCollateralUSD * ltv) / 10_000;
            availableBorrowsUSD = maxBorrowUSD > totalDebtUSD ? maxBorrowUSD - totalDebtUSD : 0;
        }

        // Calculate health factor
        if (totalDebtUSD == 0) {
            healthFactor = type(uint256).max;
        } else {
            healthFactor = (totalCollateralUSD * currentLiquidationThreshold).wadDiv(totalDebtUSD * 10_000);
        }
    }

    /// @notice Iterates all reserves to accumulate a user's collateral and debt positions
    function _calculateUserPositions(address user)
        private
        view
        returns (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,
            uint256 weightedThreshold,
            uint256 weightedLtv
        )
    {
        for (uint256 i = 0; i < _reservesList.length; ) {
            address asset = _reservesList[i];
            ReserveData storage reserve = _reserves[asset];
            uint256 assetPrice = oracle.getAssetPrice(asset);

            if (_userSuppliedAssets[user][asset]) {
                uint256 collateralUSD = _getUserCollateralUSD(user, reserve, assetPrice);
                totalCollateralUSD += collateralUSD;
                weightedThreshold += collateralUSD * reserve.liquidationThreshold;
                weightedLtv += collateralUSD * reserve.ltv;
            }

            if (_userBorrowedAssets[user][asset]) {
                totalDebtUSD += _getUserDebtUSD(user, reserve, assetPrice);
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Returns a user's collateral value in USD for a single reserve
    function _getUserCollateralUSD(
        address user,
        ReserveData storage reserve,
        uint256 assetPrice
    ) private view returns (uint256) {
        uint256 userCollateral = AToken(reserve.aTokenAddress).balanceOfWithIndex(user, reserve.liquidityIndex);
        return userCollateral.wadMul(assetPrice);
    }

    /// @notice Returns a user's debt value in USD for a single reserve
    function _getUserDebtUSD(
        address user,
        ReserveData storage reserve,
        uint256 assetPrice
    ) private view returns (uint256) {
        uint256 userDebt = DebtToken(reserve.debtTokenAddress).balanceOfWithIndex(user, reserve.variableBorrowIndex);
        return userDebt.wadMul(assetPrice);
    }

    /// @notice Checks if a user has any outstanding debt
    function _hasDebt(address user) internal view returns (bool) {
        for (uint256 i = 0; i < _reservesList.length; ) {
            if (_userBorrowedAssets[user][_reservesList[i]]) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    /// @notice Updates the liquidity and borrow indexes for a reserve
    /// @dev Accumulates interest since last update using compound interest formula
    /// @param asset The asset whose indexes to update
    function _updateIndexes(address asset) internal {
        ReserveData storage reserve = _reserves[asset];

        if (reserve.lastUpdateTimestamp == uint40(block.timestamp)) {
            return; // Already updated this block
        }

        uint256 timeDelta;
        unchecked {
            timeDelta = block.timestamp - reserve.lastUpdateTimestamp;
        }

        if (timeDelta == 0) return;

        // Update liquidity index: liquidityIndex *= (1 + liquidityRate * timeDelta / SECONDS_PER_YEAR)
        if (reserve.currentLiquidityRate > 0) {
            uint256 liquidityAccumulator;
            unchecked {
                liquidityAccumulator = (uint256(reserve.currentLiquidityRate) * timeDelta) / 365 days;
            }
            uint256 newLiquidityIndex = uint256(reserve.liquidityIndex).rayMul(
                WadRayMath.RAY + liquidityAccumulator
            );
            reserve.liquidityIndex = uint128(newLiquidityIndex);
        }

        // Update variable borrow index
        if (reserve.currentVariableBorrowRate > 0) {
            uint256 borrowAccumulator;
            unchecked {
                borrowAccumulator = (uint256(reserve.currentVariableBorrowRate) * timeDelta) / 365 days;
            }
            uint256 newBorrowIndex = uint256(reserve.variableBorrowIndex).rayMul(
                WadRayMath.RAY + borrowAccumulator
            );
            reserve.variableBorrowIndex = uint128(newBorrowIndex);
        }

        reserve.lastUpdateTimestamp = uint40(block.timestamp);
    }

    /// @notice Updates interest rates for a reserve based on current utilization
    /// @param asset The asset whose rates to update
    function _updateInterestRates(address asset) internal {
        ReserveData storage reserve = _reserves[asset];

        // Calculate available liquidity and total borrows
        uint256 availableLiquidity = IERC20(asset).balanceOf(address(this));
        DebtToken debtToken = DebtToken(reserve.debtTokenAddress);
        uint256 totalBorrows = debtToken.totalSupplyWithIndex(reserve.variableBorrowIndex);

        // Get new rates from strategy
        IInterestRateStrategy strategy = IInterestRateStrategy(reserve.interestRateStrategy);
        (uint256 liquidityRate, uint256 borrowRate) = strategy.calculateInterestRates(
            availableLiquidity,
            totalBorrows
        );

        reserve.currentLiquidityRate = uint128(liquidityRate);
        reserve.currentVariableBorrowRate = uint128(borrowRate);
    }
}

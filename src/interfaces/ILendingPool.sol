// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title ILendingPool
/// @notice Interface for the main LendX lending pool
interface ILendingPool {
    // ============================================================
    //                          STRUCTS
    // ============================================================

    struct ReserveData {
        // Slot 1: Indexes (uint128 each = 1 slot)
        uint128 liquidityIndex;
        uint128 variableBorrowIndex;
        // Slot 2: Current rates (uint128 each = 1 slot)
        uint128 currentLiquidityRate;
        uint128 currentVariableBorrowRate;
        // Slot 3: Config packed
        uint40 lastUpdateTimestamp;
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        uint16 reserveFactor;
        bool active;
        bool frozen;
        bool borrowingEnabled;
        // Slot 4+: Addresses
        address aTokenAddress;
        address debtTokenAddress;
        address interestRateStrategy;
    }

    // ============================================================
    //                          EVENTS
    // ============================================================

    event Supply(address indexed asset, address indexed user, address indexed onBehalfOf, uint256 amount);
    event Withdraw(address indexed asset, address indexed user, address indexed to, uint256 amount);
    event Borrow(address indexed asset, address indexed user, uint256 amount);
    event Repay(address indexed asset, address indexed user, address indexed onBehalfOf, uint256 amount);
    event LiquidationCall(
        address indexed collateralAsset,
        address indexed debtAsset,
        address indexed borrower,
        uint256 debtToCover,
        uint256 collateralSeized,
        address liquidator
    );
    event FlashLoan(address indexed receiver, address indexed asset, uint256 amount, uint256 fee);

    // ============================================================
    //                      USER FUNCTIONS
    // ============================================================

    /// @notice Supplies an amount of underlying asset into the reserve
    /// @param asset The address of the underlying ERC-20 token
    /// @param amount The amount to supply (in token decimals)
    /// @param onBehalfOf The address that will receive the aTokens
    /// @return The amount of aTokens minted
    function supply(address asset, uint256 amount, address onBehalfOf) external returns (uint256);

    /// @notice Withdraws an amount of underlying asset from the reserve
    /// @param asset The address of the underlying ERC-20 token
    /// @param amount The amount to withdraw (in token decimals)
    /// @param to The address that will receive the underlying tokens
    /// @return The final amount withdrawn
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    /// @notice Borrows an amount of asset against deposited collateral
    /// @param asset The address of the underlying ERC-20 token to borrow
    /// @param amount The amount to borrow (in token decimals)
    function borrow(address asset, uint256 amount) external;

    /// @notice Repays a borrowed amount on behalf of a user
    /// @param asset The address of the borrowed ERC-20 token
    /// @param amount The amount to repay (in token decimals), use type(uint256).max for full repayment
    /// @param onBehalfOf The address of the user whose debt is being repaid
    /// @return The final amount repaid
    function repay(address asset, uint256 amount, address onBehalfOf) external returns (uint256);

    /// @notice Liquidates an undercollateralized position
    /// @param collateralAsset The address of the collateral asset to seize
    /// @param debtAsset The address of the debt asset to repay
    /// @param borrower The address of the borrower being liquidated
    /// @param debtToCover The amount of debt to cover (in debt asset decimals)
    function liquidate(
        address collateralAsset,
        address debtAsset,
        address borrower,
        uint256 debtToCover
    ) external;

    /// @notice Executes a flash loan — borrow and repay within a single transaction
    /// @param receiverAddress The address of the contract receiving the flash loan
    /// @param asset The address of the asset to flash borrow
    /// @param amount The amount to flash borrow
    /// @param params Arbitrary bytes to pass to the receiver's executeOperation
    function flashLoan(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params
    ) external;

    // ============================================================
    //                      VIEW FUNCTIONS
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
        returns (
            uint256 totalCollateralUSD,
            uint256 totalDebtUSD,
            uint256 availableBorrowsUSD,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    /// @notice Returns the reserve data for a given asset
    /// @param asset The address of the underlying asset
    /// @return The ReserveData struct
    function getReserveData(address asset) external view returns (ReserveData memory);

    /// @notice Returns the USD price of an asset from the oracle
    /// @param asset The address of the asset
    /// @return The price in WAD (18 decimals)
    function getAssetPrice(address asset) external view returns (uint256);
}

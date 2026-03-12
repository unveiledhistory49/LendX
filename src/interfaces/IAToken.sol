// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IAToken
/// @notice Interface for the interest-bearing aToken
/// @dev aToken balances grow over time as interest accrues via the liquidity index
interface IAToken {
    // ============================================================
    //                          EVENTS
    // ============================================================

    event Mint(address indexed user, uint256 amount, uint256 index);
    event Burn(address indexed user, address indexed to, uint256 amount, uint256 index);

    // ============================================================
    //                       FUNCTIONS
    // ============================================================

    /// @notice Mints aTokens to a user on supply
    /// @dev Only callable by the LendingPool. Amount is scaled by the liquidity index.
    /// @param user The address of the user receiving the aTokens
    /// @param amount The amount of underlying asset supplied (not scaled)
    /// @param index The current liquidity index (RAY)
    /// @return True if this is the user's first mint (new depositor)
    function mint(address user, uint256 amount, uint256 index) external returns (bool);

    /// @notice Burns aTokens on withdrawal
    /// @dev Only callable by the LendingPool. Amount is scaled by the liquidity index.
    /// @param user The address of the user whose aTokens are being burned
    /// @param to The address receiving the underlying asset
    /// @param amount The amount of underlying asset being withdrawn (not scaled)
    /// @param index The current liquidity index (RAY)
    function burn(address user, address to, uint256 amount, uint256 index) external;

    /// @notice Returns the scaled balance of a user (stored balance, before index multiplication)
    /// @param user The address of the user
    /// @return The scaled balance
    function scaledBalanceOf(address user) external view returns (uint256);

    /// @notice Returns the scaled total supply
    /// @return The scaled total supply
    function scaledTotalSupply() external view returns (uint256);

    /// @notice Returns the address of the underlying asset
    /// @return The underlying asset address
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    /// @notice Returns the address of the LendingPool
    /// @return The pool address
    function POOL() external view returns (address);
}

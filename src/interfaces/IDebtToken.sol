// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IDebtToken
/// @notice Interface for the non-transferable debt tracking token
/// @dev Debt tokens cannot be transferred — transfer() and transferFrom() must revert
interface IDebtToken {
    // ============================================================
    //                          EVENTS
    // ============================================================

    event Mint(address indexed user, uint256 amount, uint256 index);
    event Burn(address indexed user, uint256 amount, uint256 index);

    // ============================================================
    //                       FUNCTIONS
    // ============================================================

    /// @notice Mints debt tokens to a user on borrow
    /// @dev Only callable by the LendingPool. Amount is scaled by the variable borrow index.
    /// @param user The address of the user taking on debt
    /// @param amount The amount of underlying asset borrowed (not scaled)
    /// @param index The current variable borrow index (RAY)
    /// @return True if this is the user's first borrow for this asset
    function mint(address user, uint256 amount, uint256 index) external returns (bool);

    /// @notice Burns debt tokens on repayment
    /// @dev Only callable by the LendingPool. Amount is scaled by the variable borrow index.
    /// @param user The address of the user repaying debt
    /// @param amount The amount of underlying asset being repaid (not scaled)
    /// @param index The current variable borrow index (RAY)
    function burn(address user, uint256 amount, uint256 index) external;

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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IPriceOracle
/// @notice Interface for the Chainlink price oracle wrapper
interface IPriceOracle {
    // ============================================================
    //                          EVENTS
    // ============================================================

    event AssetFeedUpdated(address indexed asset, address indexed oldFeed, address indexed newFeed);

    // ============================================================
    //                       FUNCTIONS
    // ============================================================

    /// @notice Returns the USD price of an asset normalized to 18 decimals
    /// @dev Includes three safety checks: positive price, staleness, and round completeness
    /// @param asset The address of the asset
    /// @return The price in 18 decimal precision
    function getAssetPrice(address asset) external view returns (uint256);

    /// @notice Sets the Chainlink price feed for an asset
    /// @dev Only callable by the contract owner
    /// @param asset The address of the asset
    /// @param feed The address of the Chainlink AggregatorV3Interface feed
    function setAssetFeed(address asset, address feed) external;

    /// @notice Returns the current price feed address for an asset
    /// @param asset The address of the asset
    /// @return The address of the Chainlink feed
    function getAssetFeed(address asset) external view returns (address);
}

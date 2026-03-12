// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

/// @title PriceOracle
/// @author LendX Protocol
/// @notice Chainlink-based price oracle with production-grade safety checks
/// @dev Implements three mandatory safety checks inspired by lessons from the Euler hack ($197M, 2023)
contract PriceOracle is IPriceOracle, Ownable2Step {
    // ============================================================
    //                       ERRORS
    // ============================================================

    error Oracle__FeedNotSet(address asset);
    error Oracle__InvalidPrice(address asset, int256 answer);
    error Oracle__StalePrice(address asset, uint256 updatedAt);
    error Oracle__IncompleteRound(address asset);
    error Oracle__InvalidAsset();
    error Oracle__InvalidFeed();

    // ============================================================
    //                       CONSTANTS
    // ============================================================

    /// @notice Maximum allowed age of oracle data before it's considered stale
    uint256 public constant STALENESS_THRESHOLD = 3600; // 1 hour

    // ============================================================
    //                       STATE
    // ============================================================

    /// @notice Mapping of asset address to Chainlink price feed
    mapping(address => AggregatorV3Interface) private s_assetFeeds;

    // ============================================================
    //                      CONSTRUCTOR
    // ============================================================

    /// @notice Initializes the oracle with the owner address
    /// @param owner The address of the contract owner
    constructor(address owner) Ownable(owner) {}

    // ============================================================
    //                   EXTERNAL FUNCTIONS
    // ============================================================

    /// @notice Returns the USD price of an asset normalized to 18 decimals
    /// @dev Performs three safety checks:
    ///      1. Price must be positive
    ///      2. Data must not be stale (within STALENESS_THRESHOLD)
    ///      3. Round must be complete (answeredInRound >= roundId)
    /// @param asset The address of the asset
    /// @return The price in 18 decimal precision
    function getAssetPrice(address asset) external view override returns (uint256) {
        AggregatorV3Interface feed = s_assetFeeds[asset];
        if (address(feed) == address(0)) revert Oracle__FeedNotSet(asset);

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();

        // CHECK 1: Price must be positive
        if (answer <= 0) revert Oracle__InvalidPrice(asset, answer);

        // CHECK 2: Data must not be stale
        if (block.timestamp - updatedAt > STALENESS_THRESHOLD) {
            revert Oracle__StalePrice(asset, updatedAt);
        }

        // CHECK 3: Round must be complete
        if (answeredInRound < roundId) revert Oracle__IncompleteRound(asset);

        // Normalize to 18 decimals regardless of feed decimals
        uint8 feedDecimals = feed.decimals();
        if (feedDecimals <= 18) {
            return uint256(answer) * (10 ** (18 - feedDecimals));
        } else {
            return uint256(answer) / (10 ** (feedDecimals - 18));
        }
    }

    /// @notice Sets the Chainlink price feed for an asset
    /// @dev Only callable by the contract owner. Emits AssetFeedUpdated.
    /// @param asset The address of the asset
    /// @param feed The address of the Chainlink AggregatorV3Interface feed
    function setAssetFeed(address asset, address feed) external override onlyOwner {
        if (asset == address(0)) revert Oracle__InvalidAsset();
        if (feed == address(0)) revert Oracle__InvalidFeed();

        address oldFeed = address(s_assetFeeds[asset]);
        s_assetFeeds[asset] = AggregatorV3Interface(feed);

        emit AssetFeedUpdated(asset, oldFeed, feed);
    }

    /// @notice Returns the current price feed address for an asset
    /// @param asset The address of the asset
    /// @return The address of the Chainlink feed
    function getAssetFeed(address asset) external view override returns (address) {
        return address(s_assetFeeds[asset]);
    }
}

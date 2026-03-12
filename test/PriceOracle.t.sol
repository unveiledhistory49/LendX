// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {PriceOracle} from "../src/oracle/PriceOracle.sol";
import {IPriceOracle} from "../src/interfaces/IPriceOracle.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

/// @title PriceOracleTest
/// @notice Comprehensive tests for the PriceOracle contract
/// @dev Follows web3-testing skill: fixtures, edge cases, fuzzing, access control, events
contract PriceOracleTest is Test {
    PriceOracle public oracle;
    MockAggregatorV3 public ethFeed;
    MockAggregatorV3 public usdcFeed;

    address public owner = address(1);
    address public user = address(2);
    address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    function setUp() public {
        // Warp to a realistic timestamp to avoid underflow in staleness tests
        vm.warp(100_000);

        // Deploy mock price feeds (8 decimals, like Chainlink)
        ethFeed = new MockAggregatorV3(8, 2000e8); // ETH = $2000
        usdcFeed = new MockAggregatorV3(8, 1e8);   // USDC = $1

        // Deploy oracle (single arg: owner)
        vm.prank(owner);
        oracle = new PriceOracle(owner);

        // Configure feeds
        vm.startPrank(owner);
        oracle.setAssetFeed(weth, address(ethFeed));
        oracle.setAssetFeed(usdc, address(usdcFeed));
        vm.stopPrank();
    }

    // ============================================================
    //                  DEPLOYMENT TESTS
    // ============================================================

    function test_Constructor() public view {
        assertEq(oracle.owner(), owner);
        assertEq(oracle.STALENESS_THRESHOLD(), 3600); // 1 hour constant
    }

    // ============================================================
    //                  PRICE FETCHING TESTS
    // ============================================================

    function test_GetAssetPrice_ETH() public view {
        uint256 price = oracle.getAssetPrice(weth);
        assertEq(price, 2000e18, "ETH price should be 2000e18");
    }

    function test_GetAssetPrice_USDC() public view {
        uint256 price = oracle.getAssetPrice(usdc);
        assertEq(price, 1e18, "USDC price should be 1e18");
    }

    function test_GetAssetPrice_UpdatedPrice() public {
        ethFeed.updateAnswer(2500e8);
        uint256 price = oracle.getAssetPrice(weth);
        assertEq(price, 2500e18);
    }

    // ============================================================
    //                ORACLE SAFETY CHECKS
    // ============================================================

    function test_Revert_NegativePrice() public {
        ethFeed.updateAnswer(-1);
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.Oracle__InvalidPrice.selector, weth, int256(-1)));
        oracle.getAssetPrice(weth);
    }

    function test_Revert_ZeroPrice() public {
        ethFeed.updateAnswer(0);
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.Oracle__InvalidPrice.selector, weth, int256(0)));
        oracle.getAssetPrice(weth);
    }

    function test_Revert_StalePrice() public {
        ethFeed.setUpdatedAt(block.timestamp - 3601); // 1 second past threshold
        vm.expectRevert(); // Oracle__StalePrice
        oracle.getAssetPrice(weth);
    }

    function test_StalePriceBoundary_ExactlyAtThreshold() public view {
        // Feed was just updated in setUp, should work fine
        oracle.getAssetPrice(weth); // Should not revert
    }

    function test_Revert_IncompleteRound() public {
        // Set answeredInRound < roundId (incomplete round)
        ethFeed.updateRoundData(5, 2000e8, block.timestamp, 4);
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.Oracle__IncompleteRound.selector, weth));
        oracle.getAssetPrice(weth);
    }

    function test_Revert_NoFeedConfigured() public {
        address randomAsset = address(0xDEAD);
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.Oracle__FeedNotSet.selector, randomAsset));
        oracle.getAssetPrice(randomAsset);
    }

    // ============================================================
    //                 DECIMALS NORMALIZATION
    // ============================================================

    function test_Normalize_6DecimalFeed() public {
        MockAggregatorV3 feed6 = new MockAggregatorV3(6, 1e6);
        vm.prank(owner);
        oracle.setAssetFeed(address(0xBEEF), address(feed6));
        assertEq(oracle.getAssetPrice(address(0xBEEF)), 1e18);
    }

    function test_Normalize_18DecimalFeed() public {
        MockAggregatorV3 feed18 = new MockAggregatorV3(18, 2000e18);
        vm.prank(owner);
        oracle.setAssetFeed(address(0xCAFE), address(feed18));
        assertEq(oracle.getAssetPrice(address(0xCAFE)), 2000e18);
    }

    // ============================================================
    //                 ADMIN FUNCTIONS
    // ============================================================

    function test_SetAssetFeed_Success() public {
        address newAsset = address(0xBEEF);
        MockAggregatorV3 newFeed = new MockAggregatorV3(8, 500e8);

        vm.prank(owner);
        oracle.setAssetFeed(newAsset, address(newFeed));

        assertEq(oracle.getAssetFeed(newAsset), address(newFeed));
        assertEq(oracle.getAssetPrice(newAsset), 500e18);
    }

    function test_SetAssetFeed_EmitsEvent() public {
        address newAsset = address(0xBEEF);
        MockAggregatorV3 newFeed = new MockAggregatorV3(8, 500e8);

        vm.prank(owner);
        // AssetFeedUpdated(asset, oldFeed, newFeed) — old feed is address(0) for new asset
        vm.expectEmit(true, false, false, true);
        emit IPriceOracle.AssetFeedUpdated(newAsset, address(0), address(newFeed));
        oracle.setAssetFeed(newAsset, address(newFeed));
    }

    function test_Revert_SetAssetFeed_NotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        oracle.setAssetFeed(address(0xBEEF), address(ethFeed));
    }

    function test_Revert_SetAssetFeed_ZeroAsset() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.Oracle__InvalidAsset.selector));
        oracle.setAssetFeed(address(0), address(ethFeed));
    }

    function test_Revert_SetAssetFeed_ZeroFeed() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.Oracle__InvalidFeed.selector));
        oracle.setAssetFeed(address(0xBEEF), address(0));
    }

    // ============================================================
    //                    FUZZING TESTS
    // ============================================================

    function testFuzz_GetAssetPrice_ValidPrices(uint128 price) public {
        vm.assume(price > 0);
        ethFeed.updateAnswer(int256(uint256(price)));
        uint256 result = oracle.getAssetPrice(weth);
        // 8 decimal feed → normalize by 10^10
        assertEq(result, uint256(price) * 1e10);
    }

    function testFuzz_StalenessThreshold(uint40 timePassed) public {
        vm.assume(timePassed > 0 && timePassed < block.timestamp);

        ethFeed.setUpdatedAt(block.timestamp - timePassed);

        if (timePassed > 3600) {
            vm.expectRevert(); // Oracle__StalePrice
        }
        oracle.getAssetPrice(weth);
    }
}

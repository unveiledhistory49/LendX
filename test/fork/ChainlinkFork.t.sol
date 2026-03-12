// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {LendingPool} from "../../src/core/LendingPool.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ChainlinkForkTest
/// @notice Tests the PriceOracle with real Chainlink feeds on Ethereum Mainnet
/// @dev Requires MAINNET_RPC_URL in .env. Run with --fork-url
contract ChainlinkForkTest is Test {
    PriceOracle public oracle;
    
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    // Chainlink Feeds on Mainnet
    address public constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    uint256 mainnetFork;

    function setUp() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) {
            return; // Skip if no RPC
        }
        mainnetFork = vm.createSelectFork(rpcUrl);
        
        oracle = new PriceOracle(address(this));
        oracle.setAssetFeed(WETH, ETH_USD_FEED);
        oracle.setAssetFeed(USDC, USDC_USD_FEED);
    }

    function test_ForkPriceFetching() public {
        if (bytes(vm.envOr("MAINNET_RPC_URL", string(""))).length == 0) {
            console.log("Skipping fork test: No MAINNET_RPC_URL");
            return;
        }
        
        uint256 ethPrice = oracle.getAssetPrice(WETH);
        uint256 usdcPrice = oracle.getAssetPrice(USDC);
        
        console.log("Mainnet ETH Price:", ethPrice / 1e18);
        console.log("Mainnet USDC Price:", usdcPrice / 1e18);
        
        assertGt(ethPrice, 0);
        assertGt(usdcPrice, 0);
        assertApproxEqAbs(usdcPrice, 1e18, 0.05e18); // USDC should be close to $1
    }
}

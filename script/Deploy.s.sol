// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {LendingPool} from "../src/core/LendingPool.sol";
import {AToken} from "../src/tokens/AToken.sol";
import {DebtToken} from "../src/tokens/DebtToken.sol";
import {PriceOracle} from "../src/oracle/PriceOracle.sol";
import {InterestRateStrategy} from "../src/interest/InterestRateStrategy.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockAggregatorV3} from "../test/mocks/MockAggregatorV3.sol";

/// @title DeployLendX
/// @notice 10-step deployment sequence for the LendX Protocol
/// @dev Refactored into modular functions to avoid "Stack too deep" errors.
contract DeployLendX is Script {
    struct CoreContracts {
        PriceOracle oracle;
        InterestRateStrategy strategy;
        LendingPool pool;
    }

    struct AssetMocks {
        MockERC20 token;
        MockAggregatorV3 feed;
    }

    struct AssetTokens {
        AToken aToken;
        DebtToken debtToken;
    }

    function run() external {
        // Hardcoded Base Sepolia Config to eliminate HelperConfig issues
        address weth = 0x4200000000000000000000000000000000000006;
        address usdc = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
        address wethFeed = 0x4aDc43ef890c6919DA35ff545f3899f31501F137;
        address wbtcFeed = 0x0Fb99723aEe6f07873Cc0977BcBf05684C27bc64;
        address usdcFeed = 0xd30e21013DB211845d71480bA7F5d9d115D66046;
        address linkFeed = 0x228723654BE8b1066D6c657159b98B4d32e54eEf;

        // Deploy Strategy
        vm.broadcast();
        InterestRateStrategy strategy = new InterestRateStrategy();

        // Deploy Oracle
        vm.broadcast();
        PriceOracle oracle = new PriceOracle(msg.sender);

        // Deploy Mocks
        vm.broadcast();
        address wbtc = address(new MockERC20("Wrapped Bitcoin", "WBTC", 8));
        vm.broadcast();
        address link = address(new MockERC20("Chainlink", "LINK", 18));
        
        vm.broadcast();
        oracle.setAssetFeed(weth, wethFeed);
        vm.broadcast();
        oracle.setAssetFeed(wbtc, wbtcFeed);
        vm.broadcast();
        oracle.setAssetFeed(usdc, usdcFeed);
        vm.broadcast();
        oracle.setAssetFeed(link, linkFeed);

        // Deploy LendingPool
        vm.broadcast();
        LendingPool pool = new LendingPool(address(oracle), msg.sender);

        // Configure Reserves
        configureAsset(pool, weth, "WETH", address(strategy), 8000, 8250, 10500);
        configureAsset(pool, wbtc, "WBTC", address(strategy), 7000, 7500, 10800);
        configureAsset(pool, usdc, "USDC", address(strategy), 8700, 8900, 10500);
        configureAsset(pool, link, "LINK", address(strategy), 6500, 7000, 11200);

        console.log("Deployed pool at:", address(pool));
    }

    function deployMock(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialPrice
    ) internal returns (AssetMocks memory) {
        MockERC20 token = new MockERC20(name, symbol, decimals);
        MockAggregatorV3 feed = new MockAggregatorV3(decimals == 6 ? 8 : decimals, int256(initialPrice));
        return AssetMocks(token, feed);
    }

    function configureAsset(
        LendingPool pool,
        address asset,
        string memory symbol,
        address strategy,
        uint16 ltv,
        uint16 threshold,
        uint16 bonus
    ) internal {
        AToken aToken = new AToken(
            address(pool),
            asset,
            string.concat("LendX interest bearing ", symbol),
            string.concat("a", symbol)
        );
        DebtToken dToken = new DebtToken(
            address(pool),
            asset,
            string.concat("LendX variable debt ", symbol),
            string.concat("variableDebt", symbol)
        );
        
        pool.addReserve(asset, address(aToken), address(dToken), strategy, ltv, threshold, bonus, 1000, true);
    }

    function writeDeploymentLogs(
        LendingPool pool,
        PriceOracle oracle,
        InterestRateStrategy strategy,
        address weth,
        address wbtc,
        address usdc,
        address link
    ) internal {
        string memory json = "deployment";
        vm.serializeAddress(json, "pool", address(pool));
        vm.serializeAddress(json, "oracle", address(oracle));
        vm.serializeAddress(json, "strategy", address(strategy));
        vm.serializeAddress(json, "weth", weth);
        vm.serializeAddress(json, "wbtc", wbtc);
        vm.serializeAddress(json, "usdc", usdc);
        string memory finalJson = vm.serializeAddress(json, "link", link);
        
        string memory fileName = string.concat("deployments/", vm.toString(block.chainid), ".json");
        vm.writeFile(fileName, finalJson);
        console.log("Deployed to:", fileName);
    }
}

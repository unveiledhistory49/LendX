// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract TestConfig is Test {
    function testBaseSepoliaConfig() public {
        // Mock chain ID for Base Sepolia
        vm.chainId(84532);
        HelperConfig config = new HelperConfig();
        (
            address weth,
            address wbtc,
            address usdc,
            address link,
            address wethFeed,
            address wbtcFeed,
            address usdcFeed,
            address linkFeed,
            uint256 deployerKey
        ) = config.activeNetworkConfig();
        
        console.log("WETH:", weth);
        console.log("WETH Feed:", wethFeed);
        console.log("Deployer Key exists?", deployerKey != 0);
    }
}

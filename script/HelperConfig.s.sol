// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";

/// @title HelperConfig
/// @notice Handles network-specific configuration (Sepolia, Base Sepolia, Anvil)
contract HelperConfig is Script {
    struct NetworkConfig {
        address weth;
        address wbtc;
        address usdc;
        address link;
        address wethFeed;
        address wbtcFeed;
        address usdcFeed;
        address linkFeed;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == 84532) {
            activeNetworkConfig = getBaseSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9, // WETH
            wbtc: 0x92F3B0865d2730Bc56188319daEF22A842f2104f, // WBTC
            usdc: 0x1C7d4B196CB0232B3044439008c7c10C1F618E4D, // USDC
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // LINK
            wethFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            usdcFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
            linkFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getBaseSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            weth: 0x4200000000000000000000000000000000000006, // WETH
            wbtc: address(0), 
            usdc: 0x036CbD53842c5426634e7929541eC2318f3dCF7e, // USDC
            link: address(0), 
            wethFeed: 0x4aDc43ef890c6919DA35ff545f3899f31501F137,
            wbtcFeed: 0x0Fb99723aEe6f07873Cc0977BcBf05684C27bc64,
            usdcFeed: 0xd30e21013DB211845d71480bA7F5d9d115D66046,
            linkFeed: 0x228723654BE8b1066D6c657159b98B4d32e54eEf,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilConfig() public view returns (NetworkConfig memory) {
        if (activeNetworkConfig.weth != address(0)) {
            return activeNetworkConfig;
        }

        return NetworkConfig({
            weth: address(0),
            wbtc: address(0),
            usdc: address(0),
            link: address(0),
            wethFeed: address(0),
            wbtcFeed: address(0),
            usdcFeed: address(0),
            linkFeed: address(0),
            deployerKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        });
    }
}

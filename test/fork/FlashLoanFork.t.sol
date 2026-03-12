// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {LendingPool} from "../../src/core/LendingPool.sol";
import {InterestRateStrategy} from "../../src/interest/InterestRateStrategy.sol";
import {AToken} from "../../src/tokens/AToken.sol";
import {DebtToken} from "../../src/tokens/DebtToken.sol";
import {PriceOracle} from "../../src/oracle/PriceOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title FlashLoanForkTest
/// @notice Tests FlashLoans with real liquidity by forking mainnet
/// @dev Requires MAINNET_RPC_URL. Demonstrates mainnet forking and account impersonation.
contract FlashLoanForkTest is Test {
    LendingPool public pool;
    PriceOracle public oracle;
    InterestRateStrategy public strategy;
    
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WETH_WHALE = 0x2feb1512183545f432736ee10D48269502bb09c0; // Arbitrary whale

    function setUp() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpcUrl).length == 0) return;
        vm.createSelectFork(rpcUrl);
        
        oracle = new PriceOracle(address(this));
        strategy = new InterestRateStrategy();
        pool = new LendingPool(address(oracle), address(this));
        
        // Setup WETH reserve
        AToken aWeth = new AToken(address(pool), WETH, "LendX aWETH", "aWETH");
        DebtToken dWeth = new DebtToken(address(pool), WETH, "LendX dWETH", "dWeth");
        pool.addReserve(WETH, address(aWeth), address(dWeth), address(strategy), 8000, 8500, 10500, 1000, true);
        
        // Fund pool with real WETH from whale
        vm.startPrank(WETH_WHALE);
        IERC20(WETH).transfer(address(pool), 1000e18);
        vm.stopPrank();
    }

    function test_ForkFlashLoan() public {
        if (bytes(vm.envOr("MAINNET_RPC_URL", string(""))).length == 0) return;
        
        FlashLoanReceiver receiver = new FlashLoanReceiver(pool);
        
        uint256 amount = 10e18;
        uint256 poolBalBefore = IERC20(WETH).balanceOf(address(pool));
        
        pool.flashLoan(address(receiver), WETH, amount, "");
        
        uint256 poolBalAfter = IERC20(WETH).balanceOf(address(pool));
        assertGt(poolBalAfter, poolBalBefore, "Pool should earn fees");
    }
}

contract FlashLoanReceiver {
    LendingPool pool;
    constructor(LendingPool _pool) { pool = _pool; }
    
    function executeOperation(address asset, uint256 amount, uint256 fee, address, bytes calldata) external returns (bool) {
        // Repay with fee
        IERC20(asset).approve(address(pool), amount + fee);
        return true;
    }
}

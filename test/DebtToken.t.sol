// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {DebtToken} from "../src/tokens/DebtToken.sol";
import {WadRayMath} from "../src/libraries/WadRayMath.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @title DebtTokenTest
/// @notice Unit tests for the DebtToken contract
/// @dev Following web3-testing skill: testing transfer restrictions and scaled accounting.
contract DebtTokenTest is Test {
    using WadRayMath for uint256;

    DebtToken public debtToken;
    MockERC20 public underlying;
    address public pool = address(100);
    address public user = address(200);
    address public other = address(300);

    uint256 public constant RAY = 1e27;

    event Mint(address indexed user, uint256 amount, uint256 index);
    event Burn(address indexed user, uint256 amount, uint256 index);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        underlying = new MockERC20("Underlying", "UND", 18);
        debtToken = new DebtToken(pool, address(underlying), "LendX Debt Token", "debtToken");
    }

    // ============================================================
    //                       DEPLOYMENT
    // ============================================================

    function test_InitialState() public {
        assertEq(debtToken.POOL(), pool);
        assertEq(debtToken.UNDERLYING_ASSET_ADDRESS(), address(underlying));
        assertEq(debtToken.name(), "LendX Debt Token");
        assertEq(debtToken.symbol(), "debtToken");
        assertEq(debtToken.decimals(), 18);
        assertEq(debtToken.scaledTotalSupply(), 0);
    }

    // ============================================================
    //                       ACCESS CONTROL
    // ============================================================

    function test_Revert_Mint_NotPool() public {
        vm.prank(other);
        vm.expectRevert(DebtToken.DebtToken__OnlyPool.selector);
        debtToken.mint(user, 100e18, RAY);
    }

    function test_Revert_Burn_NotPool() public {
        vm.prank(other);
        vm.expectRevert(DebtToken.DebtToken__OnlyPool.selector);
        debtToken.burn(user, 100e18, RAY);
    }

    // ============================================================
    //                          MINTING
    // ============================================================

    function test_Mint_Success() public {
        uint256 amount = 100e18;
        uint256 index = 1.1e27;
        uint256 expectedScaled = amount.rayDiv(index);

        vm.startPrank(pool);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit Mint(user, amount, index);

        bool isFirst = debtToken.mint(user, amount, index);
        vm.stopPrank();

        assertTrue(isFirst);
        assertEq(debtToken.scaledBalanceOf(user), expectedScaled);
        // balanceOf() falls back to scaledBalance because POOL (address(100)) has no deployed code.
        // This tests the safe fallback path. The real interest-bearing path is tested via balanceOfWithIndex.
        assertEq(debtToken.balanceOf(user), expectedScaled, "Fallback: balanceOf == scaledBalance when POOL has no code");
        // Test the real interest-bearing calculation explicitly:
        assertEq(debtToken.balanceOfWithIndex(user, index), amount, "balanceOfWithIndex should return original amount");
    }

    function test_Revert_Mint_ZeroAmount() public {
        vm.prank(pool);
        vm.expectRevert(DebtToken.DebtToken__InvalidMintAmount.selector);
        debtToken.mint(user, 0, RAY);
    }

    // ============================================================
    //                          BURNING
    // ============================================================

    function test_Burn_Success() public {
        uint256 mintAmount = 100e18;
        uint256 burnAmount = 30e18;
        uint256 index = RAY;

        vm.startPrank(pool);
        debtToken.mint(user, mintAmount, index);

        vm.expectEmit(true, true, true, true);
        emit Transfer(user, address(0), burnAmount);
        vm.expectEmit(true, true, true, true);
        emit Burn(user, burnAmount, index);

        debtToken.burn(user, burnAmount, index);
        vm.stopPrank();

        assertEq(debtToken.scaledBalanceOf(user), 70e18);
    }

    function test_Revert_Burn_ZeroAmount() public {
        vm.prank(pool);
        vm.expectRevert(DebtToken.DebtToken__InvalidBurnAmount.selector);
        debtToken.burn(user, 0, RAY);
    }

    function test_Revert_Burn_ExceedsBalance() public {
        vm.startPrank(pool);
        debtToken.mint(user, 100e18, RAY);
        
        vm.expectRevert(abi.encodeWithSelector(DebtToken.DebtToken__BurnExceedsBalance.selector, 101e18, 100e18));
        debtToken.burn(user, 101e18, RAY);
        vm.stopPrank();
    }

    // ============================================================
    //                 TRANSFER RESTRICTIONS
    // ============================================================

    function test_Revert_Transfer() public {
        vm.expectRevert(DebtToken.DebtToken__TransferNotAllowed.selector);
        debtToken.transfer(other, 10e18);
    }

    function test_Revert_TransferFrom() public {
        vm.expectRevert(DebtToken.DebtToken__TransferNotAllowed.selector);
        debtToken.transferFrom(user, other, 10e18);
    }

    function test_Revert_Approve() public {
        vm.expectRevert(DebtToken.DebtToken__TransferNotAllowed.selector);
        debtToken.approve(other, 10e18);
    }

    function test_Allowance_ReturnsZero() public {
        assertEq(debtToken.allowance(user, other), 0);
    }

    // ============================================================
    //                       VIEW FUNCTIONS
    // ============================================================

    function test_BalanceOfWithIndex() public {
        uint256 amount = 100e18;
        uint256 viewIndex = 1.2e27;

        vm.prank(pool);
        debtToken.mint(user, amount, RAY);

        assertEq(debtToken.balanceOfWithIndex(user, viewIndex), 120e18);
    }

    function test_TotalSupplyWithIndex() public {
        vm.startPrank(pool);
        debtToken.mint(user, 100e18, RAY);
        debtToken.mint(other, 200e18, RAY);
        vm.stopPrank();

        assertEq(debtToken.totalSupplyWithIndex(1.5e27), 450e18);
    }
}

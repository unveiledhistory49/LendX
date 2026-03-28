// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {AToken} from "../src/tokens/AToken.sol";
import {WadRayMath} from "../src/libraries/WadRayMath.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @title ATokenTest
/// @notice Unit tests for the AToken contract
/// @dev Following web3-testing skill: testing access control, scaled accounting, and events.
contract ATokenTest is Test {
    using WadRayMath for uint256;

    AToken public aToken;
    MockERC20 public underlying;
    address public pool = address(100);
    address public user = address(200);
    address public other = address(300);

    uint256 public constant RAY = 1e27;

    event Mint(address indexed user, uint256 amount, uint256 index);
    event Burn(address indexed user, address indexed to, uint256 amount, uint256 index);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        underlying = new MockERC20("Underlying", "UND", 18);
        aToken = new AToken(pool, address(underlying), "LendX aToken", "aToken");
    }

    // ============================================================
    //                       DEPLOYMENT
    // ============================================================

    function test_InitialState() public {
        assertEq(aToken.POOL(), pool);
        assertEq(aToken.UNDERLYING_ASSET_ADDRESS(), address(underlying));
        assertEq(aToken.name(), "LendX aToken");
        assertEq(aToken.symbol(), "aToken");
        assertEq(aToken.decimals(), 18);
        assertEq(aToken.scaledTotalSupply(), 0);
    }

    // ============================================================
    //                       ACCESS CONTROL
    // ============================================================

    function test_Revert_Mint_NotPool() public {
        vm.prank(other);
        vm.expectRevert(AToken.AToken__OnlyPool.selector);
        aToken.mint(user, 100e18, RAY);
    }

    function test_Revert_Burn_NotPool() public {
        vm.prank(other);
        vm.expectRevert(AToken.AToken__OnlyPool.selector);
        aToken.burn(user, user, 100e18, RAY);
    }

    // ============================================================
    //                          MINTING
    // ============================================================

    function test_Mint_Success() public {
        uint256 amount = 100e18;
        uint256 index = 1.2e27; // 1.2 RAY
        uint256 expectedScaled = amount.rayDiv(index);

        vm.startPrank(pool);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit Mint(user, amount, index);

        bool isFirst = aToken.mint(user, amount, index);
        vm.stopPrank();

        assertTrue(isFirst);
        assertEq(aToken.scaledBalanceOf(user), expectedScaled);
        assertEq(aToken.scaledTotalSupply(), expectedScaled);
    }

    function test_Mint_MultipleTimes() public {
        vm.startPrank(pool);
        aToken.mint(user, 100e18, RAY);
        bool isFirst = aToken.mint(user, 50e18, RAY);
        vm.stopPrank();

        assertFalse(isFirst);
        assertEq(aToken.scaledBalanceOf(user), 150e18);
    }

    function test_Revert_Mint_ZeroAmount() public {
        vm.prank(pool);
        vm.expectRevert(AToken.AToken__InvalidMintAmount.selector);
        aToken.mint(user, 0, RAY);
    }

    // ============================================================
    //                          BURNING
    // ============================================================

    function test_Burn_Success() public {
        uint256 mintAmount = 100e18;
        uint256 burnAmount = 40e18;
        uint256 index = RAY;

        vm.startPrank(pool);
        aToken.mint(user, mintAmount, index);

        vm.expectEmit(true, true, true, true);
        emit Transfer(user, address(0), burnAmount);
        vm.expectEmit(true, true, true, true);
        emit Burn(user, user, burnAmount, index);

        aToken.burn(user, user, burnAmount, index);
        vm.stopPrank();

        assertEq(aToken.scaledBalanceOf(user), 60e18);
        assertEq(aToken.scaledTotalSupply(), 60e18);
    }

    function test_Revert_Burn_ZeroAmount() public {
        vm.prank(pool);
        vm.expectRevert(AToken.AToken__InvalidBurnAmount.selector);
        aToken.burn(user, user, 0, RAY);
    }

    function test_Revert_Burn_ExceedsBalance() public {
        vm.startPrank(pool);
        aToken.mint(user, 100e18, RAY);
        
        vm.expectRevert(abi.encodeWithSelector(AToken.AToken__BurnExceedsBalance.selector, 101e18, 100e18));
        aToken.burn(user, user, 101e18, RAY);
        vm.stopPrank();
    }

    // ============================================================
    //                       VIEW FUNCTIONS
    // ============================================================

    function test_BalanceOfWithIndex() public {
        uint256 amount = 100e18;
        uint256 mintIndex = 1.0e27;
        uint256 viewIndex = 1.5e27;

        vm.prank(pool);
        aToken.mint(user, amount, mintIndex);

        assertEq(aToken.balanceOfWithIndex(user, viewIndex), 150e18);
    }

    function test_TotalSupplyWithIndex() public {
        vm.startPrank(pool);
        aToken.mint(user, 100e18, RAY);
        aToken.mint(other, 200e18, RAY);
        vm.stopPrank();

        assertEq(aToken.totalSupplyWithIndex(2e27), 600e18);
    }

    // ============================================================
    //                          FUZZING
    // ============================================================

    function testFuzz_MintAndBurn(uint256 amount, uint256 index) public {
        // Minimum of 1e9 avoids dust deposits where rayDiv(amount, index) rounds to 0
        amount = bound(amount, 1e9, 1e30);
        index = bound(index, 1e27, 1e36); // Index >= 1 RAY

        vm.startPrank(pool);
        aToken.mint(user, amount, index);
        assertEq(aToken.scaledBalanceOf(user), amount.rayDiv(index));

        aToken.burn(user, user, amount, index);
        assertEq(aToken.scaledBalanceOf(user), 0);
        vm.stopPrank();
    }
}

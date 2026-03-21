// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAToken} from "../interfaces/IAToken.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";

/// @title AToken
/// @author LendX Protocol
/// @notice Interest-bearing receipt token issued when users deposit into LendX
/// @dev Balances grow over time via the liquidity index — no loops, no per-block writes.
///      balanceOf(user) = scaledBalance × liquidityIndex / RAY
///      This is the same pattern used by Aave V3's aTokens for gas-efficient interest accrual.
///
///      IMPORTANT: This contract inherits ERC20 for the `name`/`symbol`/`decimals` interface
///      but manages its own scaled balance accounting. Transfer events are emitted manually
///      on mint/burn to comply with ERC-20 spec (with address(0) as from/to).
contract AToken is ERC20, IAToken {
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    // ============================================================
    //                       ERRORS
    // ============================================================

    error AToken__OnlyPool();
    error AToken__InvalidMintAmount();
    error AToken__InvalidBurnAmount();
    error AToken__BurnExceedsBalance(uint256 amount, uint256 balance);

    // ============================================================
    //                    IMMUTABLES
    // ============================================================

    /// @notice Address of the LendingPool contract
    address public immutable override POOL;

    /// @notice Address of the underlying ERC-20 asset
    address public immutable override UNDERLYING_ASSET_ADDRESS;

    // ============================================================
    //                       STATE
    // ============================================================

    /// @dev Scaled balances — the actual stored balance before index multiplication
    mapping(address => uint256) private _scaledBalances;

    /// @dev Scaled total supply
    uint256 private _scaledTotalSupply;

    // ============================================================
    //                     MODIFIERS
    // ============================================================

    modifier onlyPool() {
        if (msg.sender != POOL) revert AToken__OnlyPool();
        _;
    }

    // ============================================================
    //                    CONSTRUCTOR
    // ============================================================

    /// @notice Creates a new aToken
    /// @param pool The address of the LendingPool
    /// @param underlyingAsset The address of the underlying ERC-20 asset
    /// @param name_ The token name (e.g., "LendX interest bearing WETH")
    /// @param symbol_ The token symbol (e.g., "aWETH")
    constructor(
        address pool,
        address underlyingAsset,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        POOL = pool;
        UNDERLYING_ASSET_ADDRESS = underlyingAsset;
    }

    // ============================================================
    //                   POOL-ONLY FUNCTIONS
    // ============================================================

    /// @notice Mints aTokens to a user on supply
    /// @dev Only callable by the LendingPool. Stores the scaled (index-divided) amount.
    /// @param user The address receiving the aTokens
    /// @param amount The amount of underlying supplied (not scaled)
    /// @param index The current liquidity index (RAY)
    /// @return isFirstMint True if this is the user's first deposit
    function mint(
        address user,
        uint256 amount,
        uint256 index
    ) external override onlyPool returns (bool isFirstMint) {
        if (amount == 0) revert AToken__InvalidMintAmount();

        isFirstMint = _scaledBalances[user] == 0;

        uint256 scaledAmount = amount.rayDiv(index);
        _scaledBalances[user] += scaledAmount;
        _scaledTotalSupply += scaledAmount;

        // Emit ERC-20 Transfer event for compliance (minting = transfer from address(0))
        emit Transfer(address(0), user, amount);
        emit Mint(user, amount, index);
    }

    /// @notice Burns aTokens on withdrawal
    /// @dev Only callable by the LendingPool. Burns the scaled (index-divided) amount.
    /// @param user The address whose aTokens are being burned
    /// @param to The address receiving the underlying asset (for event tracking)
    /// @param amount The amount of underlying being withdrawn (not scaled)
    /// @param index The current liquidity index (RAY)
    function burn(
        address user,
        address to,
        uint256 amount,
        uint256 index
    ) external override onlyPool {
        if (amount == 0) revert AToken__InvalidBurnAmount();

        uint256 scaledAmount = amount.rayDiv(index);
        uint256 userScaledBalance = _scaledBalances[user];

        if (scaledAmount > userScaledBalance) {
            revert AToken__BurnExceedsBalance(amount, userScaledBalance.rayMul(index));
        }

        _scaledBalances[user] = userScaledBalance - scaledAmount;
        _scaledTotalSupply -= scaledAmount;

        // Emit ERC-20 Transfer event for compliance (burning = transfer to address(0))
        emit Transfer(user, address(0), amount);
        emit Burn(user, to, amount, index);
    }

    // ============================================================
    //                    VIEW FUNCTIONS
    // ============================================================

    /// @notice Returns the actual balance including accrued interest
    /// @dev Queries the pool for the current liquidity index to compute real balance.
    ///      balanceOf = scaledBalance × liquidityIndex / RAY
    /// @param user The address of the user
    /// @return The user's balance including interest
    function balanceOf(address user) public view override returns (uint256) {
        uint256 scaledBalance = _scaledBalances[user];
        if (scaledBalance == 0) return 0;

        try IPoolForIndex(POOL).getReserveData(UNDERLYING_ASSET_ADDRESS) returns (
            IPoolForIndex.ReserveDataView memory data
        ) {
            if (data.liquidityIndex > 0) {
                return scaledBalance.rayMul(uint256(data.liquidityIndex));
            }
        } catch {}

        return scaledBalance; // safe fallback during construction only
    }

    /// @notice Returns the balance with a given liquidity index applied
    /// @dev This is the primary way to get the actual balance with interest
    /// @param user The address of the user
    /// @param index The liquidity index to apply (RAY)
    /// @return The user's balance including interest for the given index
    function balanceOfWithIndex(address user, uint256 index) external view returns (uint256) {
        return _scaledBalances[user].rayMul(index);
    }

    /// @notice Returns the raw scaled balance (stored balance, before index multiplication)
    /// @param user The address of the user
    /// @return The scaled balance
    function scaledBalanceOf(address user) external view override returns (uint256) {
        return _scaledBalances[user];
    }

    /// @notice Returns the total supply (scaled, without index applied)
    /// @return The total supply (scaled)
    function totalSupply() public view override returns (uint256) {
        return _scaledTotalSupply;
    }

    /// @notice Returns the scaled total supply
    /// @return The scaled total supply
    function scaledTotalSupply() external view override returns (uint256) {
        return _scaledTotalSupply;
    }

    /// @notice Returns the total supply with a given liquidity index applied
    /// @param index The liquidity index to apply (RAY)
    /// @return The total supply including interest
    function totalSupplyWithIndex(uint256 index) external view returns (uint256) {
        return _scaledTotalSupply.rayMul(index);
    }

    // ============================================================
    //                  INTERNAL FUNCTIONS
    // ============================================================


}

/// @dev Minimal interface just to get the reserve data for index lookup
interface IPoolForIndex {
    struct ReserveDataView {
        uint128 liquidityIndex;
        uint128 variableBorrowIndex;
        uint128 currentLiquidityRate;
        uint128 currentVariableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        uint16 reserveFactor;
        bool active;
        bool frozen;
        bool borrowingEnabled;
        address aTokenAddress;
        address debtTokenAddress;
        address interestRateStrategy;
    }

    function getReserveData(address asset) external view returns (ReserveDataView memory);
}

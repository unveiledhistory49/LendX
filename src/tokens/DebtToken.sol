// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";

/// @title DebtToken
/// @author LendX Protocol
/// @notice Non-transferable token tracking user debt in the LendX protocol
/// @dev Uses the same scaled balance pattern as AToken but with variableBorrowIndex.
///      ALL transfer-related functions are overridden to revert — debt cannot be moved.
///      This prevents debt transfer exploits common in naive lending protocol implementations.
///
///      Inherits ERC20 for name/symbol/decimals only. Transfer events are emitted
///      on mint/burn for ERC-20 spec compliance.
contract DebtToken is ERC20, IDebtToken {
    using WadRayMath for uint256;

    // ============================================================
    //                       ERRORS
    // ============================================================

    error DebtToken__OnlyPool();
    error DebtToken__TransferNotAllowed();
    error DebtToken__InvalidMintAmount();
    error DebtToken__InvalidBurnAmount();
    error DebtToken__BurnExceedsBalance(uint256 amount, uint256 balance);

    // ============================================================
    //                    IMMUTABLES
    // ============================================================

    /// @notice Address of the LendingPool contract
    address public immutable override POOL;

    /// @notice Address of the underlying ERC-20 asset this debt represents
    address public immutable override UNDERLYING_ASSET_ADDRESS;

    // ============================================================
    //                       STATE
    // ============================================================

    /// @dev Scaled balances — stored balance before index multiplication
    mapping(address => uint256) private _scaledBalances;

    /// @dev Scaled total supply
    uint256 private _scaledTotalSupply;

    // ============================================================
    //                     MODIFIERS
    // ============================================================

    modifier onlyPool() {
        if (msg.sender != POOL) revert DebtToken__OnlyPool();
        _;
    }

    // ============================================================
    //                    CONSTRUCTOR
    // ============================================================

    /// @notice Creates a new debt token
    /// @param pool The address of the LendingPool
    /// @param underlyingAsset The address of the underlying borrowed asset
    /// @param name_ The token name (e.g., "LendX variable debt USDC")
    /// @param symbol_ The token symbol (e.g., "variableDebtUSDC")
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

    /// @notice Mints debt tokens to a user on borrow
    /// @dev Only callable by the LendingPool. Stores the scaled (index-divided) amount.
    /// @param user The address of the borrower
    /// @param amount The amount of underlying borrowed (not scaled)
    /// @param index The current variable borrow index (RAY)
    /// @return isFirstBorrow True if this is the user's first borrow of this asset
    function mint(
        address user,
        uint256 amount,
        uint256 index
    ) external override onlyPool returns (bool isFirstBorrow) {
        if (amount == 0) revert DebtToken__InvalidMintAmount();

        isFirstBorrow = _scaledBalances[user] == 0;

        uint256 scaledAmount = amount.rayDiv(index);
        _scaledBalances[user] += scaledAmount;
        _scaledTotalSupply += scaledAmount;

        // Emit ERC-20 Transfer event for compliance (minting = transfer from address(0))
        emit Transfer(address(0), user, amount);
        emit Mint(user, amount, index);
    }

    /// @notice Burns debt tokens on repayment
    /// @dev Only callable by the LendingPool. Burns the scaled (index-divided) amount.
    /// @param user The address of the user repaying
    /// @param amount The amount of underlying being repaid (not scaled)
    /// @param index The current variable borrow index (RAY)
    function burn(
        address user,
        uint256 amount,
        uint256 index
    ) external override onlyPool {
        if (amount == 0) revert DebtToken__InvalidBurnAmount();

        uint256 scaledAmount = amount.rayDiv(index);
        uint256 userScaledBalance = _scaledBalances[user];

        if (scaledAmount > userScaledBalance) {
            revert DebtToken__BurnExceedsBalance(amount, userScaledBalance.rayMul(index));
        }

        _scaledBalances[user] = userScaledBalance - scaledAmount;
        _scaledTotalSupply -= scaledAmount;

        // Emit ERC-20 Transfer event for compliance (burning = transfer to address(0))
        emit Transfer(user, address(0), amount);
        emit Burn(user, amount, index);
    }

    // ============================================================
    //                 TRANSFER RESTRICTIONS
    // ============================================================

    /// @notice Transfers are not allowed for debt tokens
    /// @dev Always reverts — debt cannot be transferred between addresses
    function transfer(address, uint256) public pure override returns (bool) {
        revert DebtToken__TransferNotAllowed();
    }

    /// @notice TransferFrom is not allowed for debt tokens
    /// @dev Always reverts — debt cannot be transferred between addresses
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert DebtToken__TransferNotAllowed();
    }

    /// @notice Approve is not allowed for debt tokens
    /// @dev Always reverts — debt cannot be approved for transfer
    function approve(address, uint256) public pure override returns (bool) {
        revert DebtToken__TransferNotAllowed();
    }

    /// @notice Allowance always returns zero for debt tokens
    function allowance(address, address) public pure override returns (uint256) {
        return 0;
    }

    // ============================================================
    //                    VIEW FUNCTIONS
    // ============================================================

    /// @notice Returns the scaled balance (stored value before index multiplication)
    /// @param user The address of the user
    /// @return The user's current debt balance (scaled)
    function balanceOf(address user) public view override returns (uint256) {
        return _scaledBalances[user];
    }

    /// @notice Returns the debt balance with a given borrow index applied
    /// @param user The address of the user
    /// @param index The variable borrow index to apply (RAY)
    /// @return The user's debt including accrued interest
    function balanceOfWithIndex(address user, uint256 index) external view returns (uint256) {
        return _scaledBalances[user].rayMul(index);
    }

    /// @notice Returns the raw scaled balance
    /// @param user The address of the user
    /// @return The scaled balance
    function scaledBalanceOf(address user) external view override returns (uint256) {
        return _scaledBalances[user];
    }

    /// @notice Returns the total supply (scaled)
    /// @return The total supply
    function totalSupply() public view override returns (uint256) {
        return _scaledTotalSupply;
    }

    /// @notice Returns the scaled total supply
    /// @return The scaled total supply
    function scaledTotalSupply() external view override returns (uint256) {
        return _scaledTotalSupply;
    }

    /// @notice Returns the total supply with a given borrow index applied
    /// @param index The variable borrow index to apply (RAY)
    /// @return The total debt including accrued interest
    function totalSupplyWithIndex(uint256 index) external view returns (uint256) {
        return _scaledTotalSupply.rayMul(index);
    }
}

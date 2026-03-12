// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Mock ERC-20 token for testing purposes
/// @dev Includes a public mint function and configurable decimals
contract MockERC20 is ERC20 {
    uint8 private immutable _decimals;

    /// @notice Creates a new mock ERC-20 token
    /// @param name_ The token name
    /// @param symbol_ The token symbol
    /// @param decimals_ The number of decimals
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    /// @notice Returns the number of decimals
    /// @return The token decimals
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Mints tokens to a specified address
    /// @dev Unrestricted — for testing only
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Burns tokens from the caller
    /// @param amount The amount of tokens to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

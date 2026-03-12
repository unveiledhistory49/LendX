// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IFlashLoanReceiver
/// @notice Interface that must be implemented by contracts receiving flash loans
interface IFlashLoanReceiver {
    /// @notice Executes an operation after receiving the flash-borrowed asset
    /// @dev Must return true on success. The receiver must approve the LendingPool
    ///      to pull back the borrowed amount + fee before returning.
    /// @param asset The address of the flash-borrowed asset
    /// @param amount The amount of the flash-borrowed asset
    /// @param fee The fee charged for the flash loan
    /// @param initiator The address that initiated the flash loan
    /// @param params Arbitrary bytes passed from the flash loan caller
    /// @return True if the operation was successful
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

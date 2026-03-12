// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title WadRayMath
/// @author LendX Protocol (modeled after Aave V3)
/// @notice Provides fixed-point math operations for WAD (1e18) and RAY (1e27) precision
/// @dev All functions operate on unsigned integers and revert on overflow
library WadRayMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant HALF_WAD = 0.5e18;

    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = 0.5e27;

    uint256 internal constant WAD_RAY_RATIO = 1e9;

    /// @notice Multiplies two WAD values, rounding half up
    /// @param a First WAD operand
    /// @param b Second WAD operand
    /// @return result The product in WAD precision
    function wadMul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        // To avoid overflow, a <= (type(uint256).max - HALF_WAD) / b
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_WAD), b))))) { revert(0, 0) }
            result := div(add(mul(a, b), HALF_WAD), WAD)
        }
    }

    /// @notice Divides two WAD values, rounding half up
    /// @param a Numerator in WAD
    /// @param b Denominator in WAD
    /// @return result The quotient in WAD precision
    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256 result) {
        assembly {
            if iszero(b) { revert(0, 0) }
            if iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), WAD)))) { revert(0, 0) }
            result := div(add(mul(a, WAD), div(b, 2)), b)
        }
    }

    /// @notice Multiplies two RAY values, rounding half up
    /// @param a First RAY operand
    /// @param b Second RAY operand
    /// @return result The product in RAY precision
    function rayMul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        assembly {
            if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_RAY), b))))) { revert(0, 0) }
            result := div(add(mul(a, b), HALF_RAY), RAY)
        }
    }

    /// @notice Divides two RAY values, rounding half up
    /// @param a Numerator in RAY
    /// @param b Denominator in RAY
    /// @return result The quotient in RAY precision
    function rayDiv(uint256 a, uint256 b) internal pure returns (uint256 result) {
        assembly {
            if iszero(b) { revert(0, 0) }
            if iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), RAY)))) { revert(0, 0) }
            result := div(add(mul(a, RAY), div(b, 2)), b)
        }
    }

    /// @notice Converts a RAY value to WAD, rounding half up
    /// @param a The RAY value to convert
    /// @return result The value in WAD precision
    function rayToWad(uint256 a) internal pure returns (uint256 result) {
        uint256 halfRatio = WAD_RAY_RATIO / 2;
        assembly {
            result := div(add(a, halfRatio), WAD_RAY_RATIO)
        }
    }

    /// @notice Converts a WAD value to RAY
    /// @param a The WAD value to convert
    /// @return result The value in RAY precision
    function wadToRay(uint256 a) internal pure returns (uint256 result) {
        assembly {
            result := mul(a, WAD_RAY_RATIO)
            if iszero(eq(div(result, WAD_RAY_RATIO), a)) { revert(0, 0) }
        }
    }
}

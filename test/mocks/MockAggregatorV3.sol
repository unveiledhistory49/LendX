// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title MockAggregatorV3
/// @notice Mock Chainlink AggregatorV3Interface for testing oracle safety checks
/// @dev Allows full control over roundId, answer, updatedAt, and answeredInRound
contract MockAggregatorV3 {
    uint8 private immutable _decimals;

    int256 private _answer;
    uint256 private _updatedAt;
    uint80 private _roundId;
    uint80 private _answeredInRound;

    /// @notice Creates a new mock aggregator
    /// @param decimals_ The number of decimals for this feed
    /// @param initialAnswer The initial price answer
    constructor(uint8 decimals_, int256 initialAnswer) {
        _decimals = decimals_;
        _answer = initialAnswer;
        _updatedAt = block.timestamp;
        _roundId = 1;
        _answeredInRound = 1;
    }

    /// @notice Returns the number of decimals
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /// @notice Returns the latest round data, matching AggregatorV3Interface
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _answer, block.timestamp, _updatedAt, _answeredInRound);
    }

    /// @notice Returns a description string
    function description() external pure returns (string memory) {
        return "MockAggregatorV3";
    }

    /// @notice Returns the version
    function version() external pure returns (uint256) {
        return 3;
    }

    // ============================================================
    //                   TEST HELPER FUNCTIONS
    // ============================================================

    /// @notice Updates the price answer
    /// @param answer The new price answer
    function updateAnswer(int256 answer) external {
        _answer = answer;
        _updatedAt = block.timestamp;
        _roundId++;
        _answeredInRound = _roundId;
    }

    /// @notice Updates the price with full control over all fields
    /// @param roundId The round ID
    /// @param answer The price answer
    /// @param updatedAt The timestamp of the update
    /// @param answeredInRound The round in which the answer was computed
    function updateRoundData(uint80 roundId, int256 answer, uint256 updatedAt, uint80 answeredInRound) external {
        _roundId = roundId;
        _answer = answer;
        _updatedAt = updatedAt;
        _answeredInRound = answeredInRound;
    }

    /// @notice Sets just the updatedAt timestamp (for staleness testing)
    /// @param updatedAt The new updatedAt timestamp
    function setUpdatedAt(uint256 updatedAt) external {
        _updatedAt = updatedAt;
    }

    /// @notice Sets the answeredInRound (for incomplete round testing)
    /// @param answeredInRound The new answeredInRound value
    function setAnsweredInRound(uint80 answeredInRound) external {
        _answeredInRound = answeredInRound;
    }
}

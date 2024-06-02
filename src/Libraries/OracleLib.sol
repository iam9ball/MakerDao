// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Olukayode Peter
 * @notice This library is used to check the chainlink oracle for stale data.
 * if a price is stale, the function will revert, and render the engine unstable -> This is by design
 * we want the engine to freeze if prices become stale.
 *
 * so if the chainlink network explodes and if you have a lot of money locked in the protocol ... too bad
 */

library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(
        AggregatorV3Interface _pricefeed
    ) public view returns (uint80, int256, uint256, uint256, uint80) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = _pricefeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (block.chainid == 11155111) {
             if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
          
        }
        }
       
          return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}

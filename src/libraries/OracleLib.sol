
// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


/**
*@title OracleLib
*@author vaishno raj
*@notice this library is used to check the chainlink oracle for state data.
* if a price is stale function will revert and render the DSCEngine unusable -this is by design
* we want the DSCEngine to freeze if prices become stale

*so id the chainlink network explodes and yu have a lot of money locked in protocol

 */

 library OracleLib{
  error OracleLib_StalePrice();
  uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface pricefeed) public view returns(
     uint80, int256, uint256, uint256,uint80   
    )
    {
     (uint80 roundId, int256 answer,uint256 startedAt,uint256 updatedAt, uint80 answeredInRound) = pricefeed.latestRoundData();   
      
      uint256 secondSince = block.timestamp-updatedAt;
      if(secondSince>TIMEOUT){
        revert OracleLib_StalePrice();
      }

      return (roundId, answer,startedAt,updatedAt,answeredInRound);
    }
 }
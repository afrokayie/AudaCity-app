// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IAggregator} from "orakl/contracts/src/v0.1/interfaces/IAggregator.sol";

contract DataFeedConsumer {
    IAggregator internal dataFeed;
    int256 public answer;
    uint80 public roundId;

    // KLAY/USD: 0xC874f389A3F49C5331490145f77c4eFE202d72E1
    // ETH/USD: 0xAEc43Fc8D4684b6A6577c3B18A1c1c6d3D55C28E
    constructor(address aggregatorProxy) {
        dataFeed = IAggregator(aggregatorProxy);
    }

    function getLatestData() public {
        (
            uint80 roundId_,
            int256 answer_ /* uint startedAt */ /* uint updatedAt */ /* uint80 answeredInRound */,
            ,
            ,

        ) = dataFeed.latestRoundData();

        answer = answer_;
        roundId = roundId_;
    }

    function decimals() public view returns (uint8) {
        return dataFeed.decimals();
    }
}

// deployed address: 0x02657Bc72D9AFB778bf3edd14De1997cD46eF7a1
// ETH / USDT : 0xD41647c63a9Ce1500982cbced9398AA1D3ec9D73
// 16475038. 0.16
// 1 * 10**8
//
// 100000000

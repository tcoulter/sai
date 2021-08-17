/// mom.sol -- admin manager

// Copyright (C) 2017  Nikolai Mushegian <nikolai@dapphub.com>
// Copyright (C) 2017  Daniel Brockman <daniel@dapphub.com>
// Copyright (C) 2017  Rain <rainbreak@riseup.net>

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.8.0;

import './ds-thing/thing.sol';
import './CDPManager.sol';
import './top.sol';
import './tap.sol';

contract SaiMom is DSThing {
    CDPManager  public  cdpManager;
    SaiTap  public  tap;
    TargetPriceFeed  public  targetPriceFeed;

    constructor(CDPManager cdpManager_, SaiTap tap_, TargetPriceFeed targetPriceFeed_) {
        cdpManager = cdpManager_;
        tap = tap_;
        targetPriceFeed = targetPriceFeed_;
    }
    // Debt ceiling
    function setCap(uint wad) public note auth {
        cdpManager.mold("cap", wad);
    }
    // Liquidation ratio
    function setMat(uint ray) public note auth {
        cdpManager.mold("mat", ray);
        uint liquidationPenalty = cdpManager.liquidationPenalty();
        uint liquidationRatio = cdpManager.liquidationRatio();
        require(liquidationPenalty >= RAY && liquidationPenalty <= liquidationRatio);
    }
    // Stability fee
    function setTax(uint ray) public note auth {
        cdpManager.mold("tax", ray);
        uint stabilityFee = cdpManager.stabilityFee();
        require(RAY <= stabilityFee);
        require(stabilityFee < 1000001100000000000000000000);  // 10% / day
    }
    // Governance fee
    function setFee(uint ray) public note auth {
        cdpManager.mold("fee", ray);
        uint fee = cdpManager.governanceFee();
        require(RAY <= fee);
        require(fee < 1000001100000000000000000000);  // 10% / day
    }
    // Liquidation fee
    function setAxe(uint ray) public note auth {
        cdpManager.mold("axe", ray);
        uint liquidationPenalty = cdpManager.liquidationPenalty();
        uint liquidationRatio = cdpManager.liquidationRatio();
        require(liquidationPenalty >= RAY && liquidationPenalty <= liquidationRatio);
    }
    // Join/Exit Spread
    function setTubGap(uint wad) public note auth {
        cdpManager.mold("gap", wad);
    }
    // ETH/USD Feed
    function setPip(DSValue pip_) public note auth {
        cdpManager.setPip(pip_);
    }
    // MKR/USD Feed
    function setPep(DSValue pep_) public note auth {
        cdpManager.setPep(pep_);
    }
    // TRFM
    function setTargetPriceFeed(TargetPriceFeed targetPriceFeed_) public note auth {
        cdpManager.setTargetPriceFeed(targetPriceFeed_);
    }
    // Boom/Bust Spread
    function setTapGap(uint wad) public note auth {
        tap.mold("gap", wad);
        uint gap = tap.gap();
        require(gap <= 1.05 ether);
        require(gap >= 0.95 ether);
    }
    // Rate of change of target price (per second)
    function setWay(uint ray) public note auth {
        require(ray < 1000001100000000000000000000);  // 10% / day
        require(ray >  999998800000000000000000000);
        targetPriceFeed.mold("way", ray);
    }
    function setHow(uint ray) public note auth {
        targetPriceFeed.tune(ray);
    }
}

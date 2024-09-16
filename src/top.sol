/// top.sol -- global settlement manager

// Copyright (C) 2017  Nikolai Mushegian <nikolai@dapphub.com>
// Copyright (C) 2017  Daniel Brockman <daniel@dapphub.com>
// Copyright (C) 2017  Rain Break <rainbreak@riseup.net>

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

import "./CDPManager.sol";
import "./tap.sol";

contract SaiTop is DSThing {
    TargetPriceFeed   public  targetPriceFeed;
    CDPManager   public  cdpManager;
    SaiTap   public  tap;

    DSToken  public  sai;
    DSToken  public  sin;
    DSToken  public  skr;
    IERC20    public  gem;

    uint256  public  fix;  // sai cage price (gem per sai)
    uint256  public  fit;  // skr cage price (ref per skr)
    uint256  public  caged;
    uint256  public  cooldown = 6 hours;

    constructor(CDPManager cdpManager_, SaiTap tap_) {
        cdpManager = cdpManager_;
        tap = tap_;

        targetPriceFeed = cdpManager.targetPriceFeed();

        sai = cdpManager.sai();
        sin = cdpManager.sin();
        skr = cdpManager.skr();
        gem = cdpManager.gem();
    }

    function era() public view virtual returns (uint) {
        return block.timestamp;
    }

    // force settlement of the system at a given price (sai per gem).
    // This is nearly the equivalent of biting all cdps at once.
    // Important consideration: the gems associated with free skr can
    // be tapped to make sai whole.
    function cage(uint price) internal {
        require(!cdpManager.off() && price != 0);
        caged = era();

        cdpManager.drip();  // collect remaining fees
        tap.heal();  // absorb any pending fees

        fit = rmul(wmul(price, targetPriceFeed.targetPrice()), cdpManager.per());
        // Most gems we can get per sai is the full balance of the cdpManager.
        // If there is no sai issued, we should still be able to cage.
        if (sai.totalSupply() == 0) {
            fix = rdiv(WAD, price);
        } else {
            fix = min(rdiv(WAD, price), rdiv(cdpManager.pie(), sai.totalSupply()));
        }

        cdpManager.cage(fit, rmul(fix, sai.totalSupply()));
        tap.cage(fix);

        tap.vent();    // burn pending sale skr
    }
    // cage by reading the last value from the feed for the price
    function cage() public note auth {
        cage(rdiv(uint(cdpManager.pip().read()), targetPriceFeed.targetPrice()));
    }

    function flow() public note {
        require(cdpManager.off());
        bool empty = cdpManager.din() == 0 && tap.fog() == 0;
        bool ended = era() > caged + cooldown;
        require(empty || ended);
        cdpManager.flow();
    }

    function setCooldown(uint cooldown_) public auth {
        cooldown = cooldown_;
    }
}

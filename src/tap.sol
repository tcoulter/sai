/// tap.sol -- liquidation engine (see also `vow`)

// Copyright (C) 2017  Nikolai Mushegian <nikolai@dapphub.com>
// Copyright (C) 2017  Daniel Brockman <daniel@dapphub.com>
// Copyright (C) 2017  Rain <rainbreak@riseup.net>

pragma solidity ^0.4.15;

import "./tub.sol";

contract SaiTap is DSThing {
    DSToken  public  sai;
    DSToken  public  sin;
    DSToken  public  skr;

    SaiTip   public  tip;
    SaiTub   public  tub;

    uint256  public  gap;  // Boom-Bust Spread
    bool     public  off;  // Cage flag
    uint256  public  fix;  // Cage price

    // Surplus
    function joy() constant returns (uint) {
        return sai.balanceOf(this);
    }
    // Bad debt
    function woe() constant returns (uint) {
        return sin.balanceOf(this);
    }
    // Collateral pending liquidation
    function fog() constant returns (uint) {
        return skr.balanceOf(this);
    }


    function SaiTap() {
        gap = WAD;
    }

    // Boom/Bust spread
    function calk(uint wad) note auth {
        gap = wad;
        require(gap <= 1.05 ether);
        require(gap >= 0.95 ether);
    }
    // Associate with tub
    function turn(SaiTub tub_) note auth {
        tub = tub_;

        sai = tub.sai();
        sin = tub.sin();
        skr = tub.skr();

        tip = tub.tip();
    }

    // Cancel debt
    function heal() note {
        var wad = min(joy(), woe());
        sai.burn(wad);
        sin.burn(wad);
    }

    // Feed price (sai per skr)
    function s2s() returns (uint) {
        var tag = tub.tag();    // ref per skr
        var par = tip.par();    // ref per sai
        return rdiv(tag, par);  // sai per skr
    }
    // Boom price (sai per skr)
    function bid(uint wad) constant returns (uint) {
        return rmul(wad, wmul(s2s(), sub(2 * WAD, gap)));
    }
    // Bust price (sai per skr)
    function ask(uint wad) constant returns (uint) {
        return rmul(wad, wmul(s2s(), gap));
    }
    function boom(uint wad) note {
        require(!off);
        heal();
        sai.push(msg.sender, bid(wad));
        skr.burn(msg.sender, wad);
    }
    function bust(uint wad) note {
        require(!off);
        heal();

        uint ash;
        if (wad > fog()) {
            skr.mint(wad - fog());
            ash = ask(wad);
            require(ash <= woe());
        } else {
            ash = ask(wad);
        }

        skr.push(msg.sender, wad);
        sai.pull(msg.sender, ash);
        heal();
    }

    //------------------------------------------------------------------

    function cage(uint fix_) note auth {
        off = true;
        fix = fix_;
    }
    function cash() note {
        require(off);
        var wad = sai.balanceOf(msg.sender);
        sai.pull(msg.sender, wad);
        tub.gem().transfer(msg.sender, rmul(wad, fix));
    }
    function vent() note {
        require(off);
        heal();
        skr.burn(fog());
    }
}

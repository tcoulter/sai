/// top.sol -- global settlement manager

// Copyright (C) 2017  Rain <rainbreak@riseup.net>

pragma solidity ^0.4.10;

import './tub.sol';
import './tap.sol';

contract Top is DSThing {
    uint128  public  fix;
    uint128  public  fit;

    Tub      public  tub;
    Tap      public  tap;

    DSVault  public  jar;
    DSVault  public  pot;
    DSVault  public  pit;

    DSDevil  public  dev;

    DSToken  public  sai;
    DSToken  public  sin;
    DSToken  public  skr;
    ERC20    public  gem;

    enum Stage { Usual, Caged, Empty }

    function Top(Tub tub_, Tap tap_) {
        tub = tub_;
        tap = tap_;

        jar = tub.jar();
        pot = tub.pot();
        pit = tap.pit();

        dev = tub.dev();

        sai = tub.sai();
        sin = tub.sin();
        skr = tub.skr();
        gem = tub.gem();
    }

    // force settlement of the system at a given price (sai per gem).
    // This is nearly the equivalent of biting all cups at once.
    // Important consideration: the gems associated with free skr can
    // be tapped to make sai whole.
    function cage(uint128 price) auth note {
        assert(tub.reg() == Tub.Stage.Usual);

        price = price * (RAY / WAD);  // cast up to ray for precision

        // bring time up to date, collecting any more fees
        tub.drip();
        // move all good debt, bad debt and surplus to the pot
        pit.push(sin, pot);
        pit.push(sai, pot);
        dev.heal(pot);       // absorb any pending fees
        pit.burn(skr);       // burn pending sale skr

        // save current gem per skr for collateral calc.
        // we need to know this to work out the skr value of a cups debt
        fit = tub.jar().per();

        // most gems we can get per sai is the full balance
        var woe = cast(sin.balanceOf(pot));
        fix = hmin(rdiv(RAY, price), rdiv(tub.pie(), woe));
        // gems needed to cover debt
        var bye = rmul(fix, woe);

        // put the gems backing sai in a safe place
        jar.push(gem, pot, bye);
        tub.cage(fit, fix);
    }
    // exchange free sai for gems after kill
    function cash() auth note {
        assert(tub.reg() == Tub.Stage.Caged || tub.reg() == Tub.Stage.Empty);

        var hai = cast(sai.balanceOf(msg.sender));
        pot.pull(sai, msg.sender);
        dev.mend(pot, hai);

        pot.push(gem, msg.sender, rmul(hai, fix));
    }
}
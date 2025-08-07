/// CDPManager.sol -- simplified CDP engine (baby brother of `vat')

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

import "./ds-thing/thing.sol";
import "./ds-token/token.sol";
import "./ds-value/value.sol";

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./TargetPriceFeed.sol";

contract CDPManagerEvents {
    event LogNewCDP(address indexed owner, bytes32 cdp);
}

contract CDPManager is DSThing, CDPManagerEvents {
    DSToken  public  sai;  // Stablecoin
    DSToken  public  sin;  // Debt (negative sai)

    DSToken  public  skr;  // Abstracted collateral
    IERC20   public  gem;  // Underlying collateral

    DSToken  public  gov;  // Governance token

    TargetPriceFeed  public  targetPriceFeed;  // Target price feed
    DSValue             public  pip;  // Reference price feed
    DSValue             public  pep;  // Governance price feed

    address  public  tap;  // Liquidator
    address  public  pit;  // Governance Vault

    uint256  public  liquidationPenalty;  // Liquidation penalty
    uint256  public  debtCeiling;  // Debt ceiling
    uint256  public  liquidationRatio;  // Liquidation ratio
    uint256  public  stabilityFee;  // Stability fee
    uint256  public  governanceFee;  // Governance fee
    uint256  public  joinExitSpread;  // Join-Exit Spread

    bool     public  off;  // Cage flag
    bool     public  out;  // Post cage exit

    uint256  public  fit;  // REF per SKR (just before settlement)

    uint256  public  rho;  // Time of last drip
    uint256         _accumulatedStabilityFeeRate;  // Accumulated Tax Rates
    uint256         _rhi;  // Accumulated Tax + Fee Rates
    uint256  public  rum;  // Total normalised debt

    uint256                   public  totalCDPs;
    mapping (bytes32 => CDP)  public  cdps;

    struct CDP {
        address  owner;      // CDP owner
        uint256  ink;      // Locked collateral (in SKR)
        uint256  art;      // Outstanding normalised debt (stabilityFee only)
        uint256  ire;      // Outstanding normalised debt
    }

    function lad(bytes32 cdp) public view returns (address) {
        return cdps[cdp].owner;
    }
    function ink(bytes32 cdp) public view returns (uint) {
        return cdps[cdp].ink;
    }
    function tab(bytes32 cdp) public returns (uint) {
        return rmul(cdps[cdp].art, chi());
    }
    function rap(bytes32 cdp) public returns (uint) {
        return sub(rmul(cdps[cdp].ire, rhi()), tab(cdp));
    }

    // Total CDP Debt
    function din() public returns (uint) {
        return rmul(rum, chi());
    }
    // Backing collateral
    function air() public view returns (uint) {
        return skr.balanceOf(address(this));
    }
    // Raw collateral
    function pie() public view returns (uint) {
        return gem.balanceOf(address(this));
    }

    //------------------------------------------------------------------

    constructor(
        DSToken  sai_,
        DSToken  sin_,
        DSToken  skr_,
        IERC20    gem_,
        DSToken  gov_,
        DSValue  pip_,
        DSValue  pep_,
        TargetPriceFeed   targetPriceFeed_,
        address  pit_
    ) {
        gem = gem_;
        skr = skr_;

        sai = sai_;
        sin = sin_;

        gov = gov_;
        pit = pit_;

        pip = pip_;
        pep = pep_;
        targetPriceFeed = targetPriceFeed_;

        liquidationPenalty = RAY;
        liquidationRatio = RAY;
        stabilityFee = RAY;
        governanceFee = RAY;
        joinExitSpread = WAD;

        _accumulatedStabilityFeeRate = RAY;
        _rhi = RAY;

        rho = era();
    }

    function era() public view virtual returns (uint) {
        return block.timestamp;
    }

    //--Risk-parameter-config-------------------------------------------

    // TODO: Clean up remnants of old variable names.
    function mold(bytes32 param, uint val) public note auth {
        if      (param == 'cap') debtCeiling = val;
        else if (param == 'mat') { require(val >= RAY); liquidationRatio = val; }
        else if (param == 'tax') { require(val >= RAY); drip(); stabilityFee = val; }
        else if (param == 'fee') { require(val >= RAY); drip(); governanceFee = val; }
        else if (param == 'axe') { require(val >= RAY); liquidationPenalty = val; }
        else if (param == 'gap') { require(val >= WAD); joinExitSpread = val; }
        else return;
    }

    //--Price-feed-setters----------------------------------------------

    function setPip(DSValue pip_) public note auth {
        pip = pip_;
    }
    function setPep(DSValue pep_) public note auth {
        pep = pep_;
    }
    function setTargetPriceFeed(TargetPriceFeed targetPriceFeed_) public note auth {
        targetPriceFeed = targetPriceFeed_;
    }

    //--Tap-setter------------------------------------------------------
    function turn(address tap_) public note {
        require(tap  == address(0));
        require(tap_ != address(0));
        tap = tap_;
    }

    //--Collateral-wrapper----------------------------------------------

    // Wrapper ratio (gem per skr)
    function per() public view returns (uint ray) {
        return skr.totalSupply() == 0 ? RAY : rdiv(pie(), skr.totalSupply());
    }
    // Join price (gem per skr)
    function ask(uint wad) public view returns (uint) {
        return rmul(wad, wmul(per(), joinExitSpread));
    }
    // Exit price (gem per skr)
    function bid(uint wad) public view returns (uint) {
        return rmul(wad, wmul(per(), sub(2 * WAD, joinExitSpread)));
    }
    function join(uint wad) public note {
        require(!off);
        require(ask(wad) > 0);
        require(gem.transferFrom(msg.sender, address(this), ask(wad)));
        skr.mint(msg.sender, wad);
    }
    function exit(uint wad) public note {
        require(!off || out);
        require(gem.transfer(msg.sender, bid(wad)));
        skr.burn(msg.sender, wad);
    }

    //--Stability-fee-accumulation--------------------------------------

    // Accumulated Rates
    function chi() public returns (uint) {
        drip();
        return _accumulatedStabilityFeeRate;
    }
    function rhi() public returns (uint) {
        drip();
        return _rhi;
    }
    function drip() public note {
        if (off) return;

        uint rho_ = era();
        uint age = rho_ - rho;
        if (age == 0) return;    // optimised
        rho = rho_;

        uint inc = RAY;

        if (stabilityFee != RAY) {  // optimised
            uint _accumulatedStabilityFeeRate_ = _accumulatedStabilityFeeRate;
            inc = rpow(stabilityFee, age);
            _accumulatedStabilityFeeRate = rmul(_accumulatedStabilityFeeRate, inc);
            sai.mint(tap, rmul(sub(_accumulatedStabilityFeeRate, _accumulatedStabilityFeeRate_), rum));
        }

        // optimised
        if (governanceFee != RAY) inc = rmul(inc, rpow(governanceFee, age));
        if (inc != RAY) _rhi = rmul(_rhi, inc);
    }


    //--CDP-risk-indicator----------------------------------------------

    // Abstracted collateral price (ref per skr)
    function tag() public view returns (uint wad) {
        return off ? fit : wmul(per(), uint(pip.read()));
    }
    // Returns true if cdp defined by cdp is well-collateralized
    function safe(bytes32 cdp) public returns (bool) {
        uint pro = rmul(tag(), ink(cdp));
        uint con = rmul(targetPriceFeed.targetPrice(), tab(cdp));
        uint min = rmul(con, liquidationRatio);
        return pro >= min;
    }


    //--CDP-operations--------------------------------------------------

    function open() public note returns (bytes32 cdp) {
        require(!off);
        totalCDPs = add(totalCDPs, 1);
        cdp = bytes32(totalCDPs);
        cdps[cdp].owner = msg.sender;
        emit LogNewCDP(msg.sender, cdp);
    }
    function give(bytes32 cdp, address guy) public note {
        require(msg.sender == cdps[cdp].owner);
        require(guy != address(0));
        cdps[cdp].owner = guy;
    }

    function lock(bytes32 cdp, uint wad) public note {
        require(!off);
        cdps[cdp].ink = add(cdps[cdp].ink, wad);
        skr.pull(msg.sender, wad);
        require(cdps[cdp].ink == 0 || cdps[cdp].ink > 0.005 ether);
    }
    function free(bytes32 cdp, uint wad) public note {
        require(msg.sender == cdps[cdp].owner);
        cdps[cdp].ink = sub(cdps[cdp].ink, wad);
        skr.push(msg.sender, wad);
        require(safe(cdp));
        require(cdps[cdp].ink == 0 || cdps[cdp].ink > 0.005 ether);
    }

    function draw(bytes32 cdp, uint wad) public note {
        require(!off);
        require(msg.sender == cdps[cdp].owner);
        require(rdiv(wad, chi()) > 0);

        cdps[cdp].art = add(cdps[cdp].art, rdiv(wad, chi()));
        rum = add(rum, rdiv(wad, chi()));

        cdps[cdp].ire = add(cdps[cdp].ire, rdiv(wad, rhi()));
        sai.mint(cdps[cdp].owner, wad);

        require(safe(cdp));
        require(sai.totalSupply() <= debtCeiling);
    }
    function wipe(bytes32 cdp, uint wad) public note {
        require(!off);

        uint owe = rmul(wad, rdiv(rap(cdp), tab(cdp)));

        cdps[cdp].art = sub(cdps[cdp].art, rdiv(wad, chi()));
        rum = sub(rum, rdiv(wad, chi()));

        cdps[cdp].ire = sub(cdps[cdp].ire, rdiv(add(wad, owe), rhi()));
        sai.burn(msg.sender, wad);

        (bytes32 val, bool ok) = pep.peek();
        if (ok && val != 0) gov.move(msg.sender, pit, wdiv(owe, uint(val)));
    }

    function shut(bytes32 cdp) public note {
        require(!off);
        require(msg.sender == cdps[cdp].owner);
        if (tab(cdp) != 0) wipe(cdp, tab(cdp));
        if (ink(cdp) != 0) free(cdp, ink(cdp));
        delete cdps[cdp];
    }

    function bite(bytes32 cdp) public note {
        require(!safe(cdp) || off);

        // Take on all of the debt, except unpaid fees
        uint rue = tab(cdp);
        sin.mint(tap, rue);
        rum = sub(rum, cdps[cdp].art);
        cdps[cdp].art = 0;
        cdps[cdp].ire = 0;

        // Amount owed in SKR, including liquidation penalty
        uint owe = rdiv(rmul(rmul(rue, liquidationPenalty), targetPriceFeed.targetPrice()), tag());

        if (owe > cdps[cdp].ink) {
            owe = cdps[cdp].ink;
        }

        skr.push(tap, owe);
        cdps[cdp].ink = sub(cdps[cdp].ink, owe);
    }

    //------------------------------------------------------------------

    function cage(uint fit_, uint jam) public note auth {
        require(!off && fit_ != 0);
        off = true;
        liquidationPenalty = RAY;
        joinExitSpread = WAD;
        fit = fit_;         // ref per skr
        require(gem.transfer(tap, jam));
    }
    function flow() public note auth {
        require(off);
        out = true;
    }
}

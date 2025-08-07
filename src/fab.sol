pragma solidity >=0.8.0;

import "./ds-auth/auth.sol";
import './ds-token/token.sol';
import './ds-guard/guard.sol';
import './ds-roles/roles.sol';
import './ds-value/value.sol';

import './mom.sol';

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GemFab {
    function newTok(string memory name) public returns (DSToken token) {
        token = new DSToken(name);
        token.setOwner(msg.sender);
    }
}

contract TargetPriceFeedDeployer {
    function deploy() public returns (TargetPriceFeed targetPriceFeed) {
        targetPriceFeed = new TargetPriceFeed(10 ** 27);
        targetPriceFeed.setOwner(msg.sender);
    }
}

contract CDPManagerDeployer {
    function deploy(DSToken sai, DSToken sin, DSToken skr, IERC20 gem, DSToken gov, DSValue pip, DSValue pep, TargetPriceFeed targetPriceFeed, address pit) public returns (CDPManager cdpManager) {
        cdpManager = new CDPManager(sai, sin, skr, gem, gov, pip, pep, targetPriceFeed, pit);
        cdpManager.setOwner(msg.sender);
    }
}

contract TapFab {
    function newTap(CDPManager cdpManager) public returns (SaiTap tap) {
        tap = new SaiTap(cdpManager);
        tap.setOwner(msg.sender);
    }
}

contract TopFab {
    function newTop(CDPManager cdpManager, SaiTap tap) public returns (SaiTop top) {
        top = new SaiTop(cdpManager, tap);
        top.setOwner(msg.sender);
    }
}

contract MomFab {
    function newMom(CDPManager cdpManager, SaiTap tap, TargetPriceFeed targetPriceFeed) public returns (SaiMom mom) {
        mom = new SaiMom(cdpManager, tap, targetPriceFeed);
        mom.setOwner(msg.sender);
    }
}

contract DadFab {
    function newDad() public returns (DSGuard dad) {
        dad = new DSGuard();
        dad.setOwner(msg.sender);
    }
}

contract DaiFab is DSAuth {
    GemFab public gemFab;
    TargetPriceFeedDeployer public targetPriceFeedDeployer;
    TapFab public tapFab;
    CDPManagerDeployer public cdpManagerDeployer;
    TopFab public topFab;
    MomFab public momFab;
    DadFab public dadFab;

    DSToken public sai;
    DSToken public sin;
    DSToken public skr;

    TargetPriceFeed public targetPriceFeed;
    CDPManager public cdpManager;
    SaiTap public tap;
    SaiTop public top;

    SaiMom public mom;
    DSGuard public dad;

    uint8 public step = 0;

    constructor(
      GemFab gemFab_, 
      TargetPriceFeedDeployer targetPriceFeedDeployer_, 
      CDPManagerDeployer cdpManagerDeployer_, 
      TapFab tapFab_, 
      TopFab topFab_, 
      MomFab momFab_, 
      DadFab dadFab_
    ) {
        gemFab = gemFab_;
        targetPriceFeedDeployer = targetPriceFeedDeployer_;
        cdpManagerDeployer = cdpManagerDeployer_;
        tapFab = tapFab_;
        topFab = topFab_;
        momFab = momFab_;
        dadFab = dadFab_;
    }

    function makeTokens() public auth {
        require(step == 0);
        sai = gemFab.newTok('DAI');
        sin = gemFab.newTok('SIN');
        skr = gemFab.newTok('PETH');
        sai.setName('Dai Stablecoin v1.0');
        sin.setName('SIN');
        skr.setName('Pooled Ether');
        step += 1;
    }

    function makeVoxTub(IERC20 gem, DSToken gov, DSValue pip, DSValue pep, address pit) public auth {
        require(step == 1);
        require(address(gem) != address(0));
        require(address(gov) != address(0));
        require(address(pip) != address(0));
        require(address(pep) != address(0));
        require(pit != address(0));
        targetPriceFeed = targetPriceFeedDeployer.deploy();
        cdpManager = cdpManagerDeployer.deploy(sai, sin, skr, gem, gov, pip, pep, targetPriceFeed, pit);
        step += 1;
    }

    function makeTapTop() public auth {
        require(step == 2);
        tap = tapFab.newTap(cdpManager);
        cdpManager.turn(address(tap));
        top = topFab.newTop(cdpManager, tap);
        step += 1;
    }

    function S(string memory s) internal pure returns (bytes4) {
        return bytes4(keccak256(abi.encodePacked(s)));
    }

    function ray(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 9;
    }

    // Liquidation Ratio   150%
    // Liquidation Penalty 13%
    // Stability Fee       0.05%
    // PETH Fee            0%
    // Boom/Bust Spread   -3%
    // Join/Exit Spread    0%
    // Debt Ceiling        0
    function configParams() public auth {
        require(step == 3);

        cdpManager.mold("cap", 0);
        cdpManager.mold("mat", ray(1.5  ether));
        cdpManager.mold("axe", ray(1.13 ether));
        cdpManager.mold("fee", 1000000000158153903837946257);  // 0.5% / year
        cdpManager.mold("tax", ray(1 ether));
        cdpManager.mold("gap", 1 ether);

        tap.mold("gap", 0.97 ether);

        step += 1;
    }

    function verifyParams() public auth {
        require(step == 4);

        require(cdpManager.debtCeiling() == 0);
        require(cdpManager.liquidationRatio() == 1500000000000000000000000000);
        require(cdpManager.liquidationPenalty() == 1130000000000000000000000000);
        require(cdpManager.governanceFee() == 1000000000158153903837946257);
        require(cdpManager.stabilityFee() == 1000000000000000000000000000);
        require(cdpManager.joinExitSpread() == 1000000000000000000);

        require(tap.gap() == 970000000000000000);

        require(targetPriceFeed.targetPrice() == 1000000000000000000000000000);
        require(targetPriceFeed.how() == 0);

        step += 1;
    }

    function configAuth(DSAuthority authority) public auth {
        require(step == 5);
        require(address(authority) != address(0));

        mom = momFab.newMom(cdpManager, tap, targetPriceFeed);
        dad = dadFab.newDad();

        targetPriceFeed.setAuthority(dad);
        targetPriceFeed.setOwner(address(0));
        cdpManager.setAuthority(dad);
        cdpManager.setOwner(address(0));
        tap.setAuthority(dad);
        tap.setOwner(address(0));
        sai.setAuthority(dad);
        sai.setOwner(address(0));
        sin.setAuthority(dad);
        sin.setOwner(address(0));
        skr.setAuthority(dad);
        skr.setOwner(address(0));

        top.setAuthority(authority);
        top.setOwner(address(0));
        mom.setAuthority(authority);
        mom.setOwner(address(0));

        dad.permit(address(top), address(cdpManager), S("cage(uint256,uint256)"));
        dad.permit(address(top), address(cdpManager), S("flow()"));
        dad.permit(address(top), address(tap), S("cage(uint256)"));

        dad.permit(address(cdpManager), address(skr), S('mint(address,uint256)'));
        dad.permit(address(cdpManager), address(skr), S('burn(address,uint256)'));

        dad.permit(address(cdpManager), address(sai), S('mint(address,uint256)'));
        dad.permit(address(cdpManager), address(sai), S('burn(address,uint256)'));

        dad.permit(address(cdpManager), address(sin), S('mint(address,uint256)'));

        dad.permit(address(tap), address(sai), S('mint(address,uint256)'));
        dad.permit(address(tap), address(sai), S('burn(address,uint256)'));
        dad.permit(address(tap), address(sai), S('burn(uint256)'));
        dad.permit(address(tap), address(sin), S('burn(uint256)'));

        dad.permit(address(tap), address(skr), S('mint(uint256)'));
        dad.permit(address(tap), address(skr), S('burn(uint256)'));
        dad.permit(address(tap), address(skr), S('burn(address,uint256)'));

        dad.permit(address(mom), address(targetPriceFeed), S("mold(bytes32,uint256)"));
        dad.permit(address(mom), address(targetPriceFeed), S("tune(uint256)"));
        dad.permit(address(mom), address(cdpManager), S("mold(bytes32,uint256)"));
        dad.permit(address(mom), address(tap), S("mold(bytes32,uint256)"));
        dad.permit(address(mom), address(cdpManager), S("setPip(address)"));
        dad.permit(address(mom), address(cdpManager), S("setPep(address)"));
        dad.permit(address(mom), address(cdpManager), S("setTargetPriceFeed(address)"));

        dad.setOwner(address(0));
        step += 1;
    }
}

pragma solidity >=0.8.0;

import "./ds-test/test.sol";

import "./ds-math/math.sol";

import './ds-token/token.sol';
import './ds-roles/roles.sol';
import './ds-value/value.sol';

import './weth9.sol';
import './mom.sol';
import './fab.sol';
import './pit.sol';
import './TargetPriceFeed.sol';

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestWarp is DSNote {
    uint256  _era;

    constructor() {
        _era = block.timestamp;
    }

    function era() public view virtual returns (uint256) {
        return _era == 0 ? block.timestamp : _era;
    }

    function warp(uint age) public note {
        _era = age == 0 ? 0 : _era + age;
    }
}

contract DevCDPManager is CDPManager, TestWarp {
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
    ) CDPManager(sai_, sin_, skr_, gem_, gov_, pip_, pep_, targetPriceFeed_, pit_) TestWarp() {}

    function era() public view override(CDPManager, TestWarp) returns (uint256) {
      return super.era();
    }
}

contract DevTop is SaiTop, TestWarp {
    constructor(CDPManager cdpManager_, SaiTap tap_) SaiTop(cdpManager_, tap_) TestWarp() {}

    function era() public view override(SaiTop, TestWarp) returns (uint256) {
      return super.era();
    }
}

contract DevTargetPriceFeed is TargetPriceFeed, TestWarp {
    constructor(uint par_) TargetPriceFeed(par_) TestWarp() {}

    function era() public view override(TargetPriceFeed, TestWarp) returns (uint256) {
      return super.era();
    }
}

contract DevTargetPriceFeedDeployer {
    function deploy() public returns (DevTargetPriceFeed targetPriceFeed) {
        targetPriceFeed = new DevTargetPriceFeed(10 ** 27);
        targetPriceFeed.setOwner(msg.sender);
    }
}

contract DevCDPManagerDeployer {
    function deploy(DSToken sai, DSToken sin, DSToken skr, DSToken gem, DSToken gov, DSValue pip, DSValue pep, TargetPriceFeed targetPriceFeed, address pit) public returns (DevCDPManager cdpManager) {
        cdpManager = new DevCDPManager(sai, sin, skr, IERC20(address(gem)), gov, pip, pep, targetPriceFeed, pit);
        cdpManager.setOwner(msg.sender);
    }
}

contract DevTopFab {
    function newTop(DevCDPManager cdpManager, SaiTap tap) public returns (DevTop top) {
        top = new DevTop(cdpManager, tap);
        top.setOwner(msg.sender);
    }
}

contract DevDadFab {
    function newDad() public returns (DSGuard dad) {
        dad = new DSGuard();
        // convenience in tests
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).sai()), bytes4(keccak256('mint(uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).sai()), bytes4(keccak256('burn(uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).sai()), bytes4(keccak256('mint(address,uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).sai()), bytes4(keccak256('burn(address,uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).sin()), bytes4(keccak256('mint(uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).sin()), bytes4(keccak256('burn(uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).sin()), bytes4(keccak256('mint(address,uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).sin()), bytes4(keccak256('burn(address,uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).skr()), bytes4(keccak256('mint(uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).skr()), bytes4(keccak256('burn(uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).skr()), bytes4(keccak256('mint(address,uint256)')));
        dad.permit(address(DaiFab(msg.sender).owner()), address(DaiFab(msg.sender).skr()), bytes4(keccak256('burn(address,uint256)')));
        dad.setOwner(msg.sender);
    }
}

contract FakePerson {
    SaiTap  public tap;
    DSToken public sai;

    constructor(SaiTap _tap) {
        tap = _tap;
        sai = tap.sai();
        sai.approve(address(tap));
    }

    function cash() public {
        tap.cash(sai.balanceOf(address(this)));
    }
}

contract SaiTestBase is DSTest, DSMath {
    DevTargetPriceFeed   targetPriceFeed;
    DevCDPManager   cdpManager;
    DevTop   top;
    SaiTap   tap;

    SaiMom   mom;

    WETH9    gem;
    DSToken  sai;
    DSToken  sin;
    DSToken  skr;
    DSToken  gov;

    GemPit   pit;

    DSValue  pip;
    DSValue  pep;
    DSRoles  dad;

    function ray(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 9;
    }
    function wad(uint256 ray_) internal pure returns (uint256) {
        return wdiv(ray_, RAY);
    }

    function mark(uint price) internal {
        pip.poke(bytes32(price));
    }
    function mark(DSToken tkn, uint price) internal {
        if (address(tkn) == address(gov)) pep.poke(bytes32(price));
        else if (address(tkn) == address(gem)) mark(price);
    }
    function warp(uint256 age) internal {
        targetPriceFeed.warp(age);
        cdpManager.warp(age);
        top.warp(age);
    }

    function setUp() public virtual {
        GemFab gemFab = new GemFab();
        DevTargetPriceFeedDeployer targetPriceFeedDeployer = new DevTargetPriceFeedDeployer();
        DevCDPManagerDeployer cdpManagerDeployer = new DevCDPManagerDeployer();
        TapFab tapFab = new TapFab();
        DevTopFab topFab = new DevTopFab();
        MomFab momFab = new MomFab();
        DevDadFab dadFab = new DevDadFab();

        DaiFab daiFab = new DaiFab(
          gemFab, 
          TargetPriceFeedDeployer(address(targetPriceFeedDeployer)), 
          CDPManagerDeployer(address(cdpManagerDeployer)), 
          tapFab, 
          TopFab(address(topFab)), 
          momFab, 
          DadFab(address(dadFab))
        );

        gem = new WETH9();
        gem.deposit{value: 100 ether}();
        gov = new DSToken('GOV');
        pip = new DSValue();
        pep = new DSValue();
        pit = new GemPit();

        daiFab.makeTokens();
        daiFab.makeVoxTub(IERC20(address(gem)), gov, pip, pep, address(pit));
        daiFab.makeTapTop();
        daiFab.configParams();
        daiFab.verifyParams();
        DSRoles authority = new DSRoles();
        authority.setRootUser(address(this), true);
        daiFab.configAuth(authority);

        sai = DSToken(daiFab.sai());
        sin = DSToken(daiFab.sin());
        skr = DSToken(daiFab.skr());
        targetPriceFeed = DevTargetPriceFeed(address(daiFab.targetPriceFeed()));
        cdpManager = DevCDPManager(address(daiFab.cdpManager()));
        tap = SaiTap(daiFab.tap());
        top = DevTop(address(daiFab.top()));
        mom = SaiMom(daiFab.mom());
        dad = DSRoles(address(daiFab.dad()));

        sai.approve(address(cdpManager));
        skr.approve(address(cdpManager));
        gem.approve(address(cdpManager), type(uint256).max);
        gov.approve(address(cdpManager));

        sai.approve(address(tap));
        skr.approve(address(tap));

        mark(1 ether);
        mark(gov, 1 ether);

        mom.setCap(20 ether);
        mom.setAxe(ray(1 ether));
        mom.setMat(ray(1 ether));
        mom.setTax(ray(1 ether));
        mom.setFee(ray(1 ether));
        mom.setTubGap(1 ether);
        mom.setTapGap(1 ether);
    }
}

contract CDPManagerTest is SaiTestBase {
    function testBasic() public {
        assertEq( skr.balanceOf(address(cdpManager)), 0 ether );
        assertEq( skr.balanceOf(address(this)), 0 ether );
        assertEq( gem.balanceOf(address(cdpManager)), 0 ether );

        // edge case
        assertEq( uint256(cdpManager.per()), ray(1 ether) );
        cdpManager.join(10 ether);
        assertEq( uint256(cdpManager.per()), ray(1 ether) );

        assertEq( skr.balanceOf(address(this)), 10 ether );
        assertEq( gem.balanceOf(address(cdpManager)), 10 ether );
        // price formula
        cdpManager.join(10 ether);
        assertEq( uint256(cdpManager.per()), ray(1 ether) );
        assertEq( skr.balanceOf(address(this)), 20 ether );
        assertEq( gem.balanceOf(address(cdpManager)), 20 ether );

        bytes32 cdp = cdpManager.open();

        assertEq( skr.balanceOf(address(this)), 20 ether );
        assertEq( skr.balanceOf(address(cdpManager)), 0 ether );
        cdpManager.lock(cdp, 10 ether); // lock skr token
        assertEq( skr.balanceOf(address(this)), 10 ether );
        assertEq( skr.balanceOf(address(cdpManager)), 10 ether );

        assertEq( sai.balanceOf(address(this)), 0 ether);
        cdpManager.draw(cdp, 5 ether);
        assertEq( sai.balanceOf(address(this)), 5 ether);


        assertEq( sai.balanceOf(address(this)), 5 ether);
        cdpManager.wipe(cdp, 2 ether);
        assertEq( sai.balanceOf(address(this)), 3 ether);

        assertEq( sai.balanceOf(address(this)), 3 ether);
        assertEq( skr.balanceOf(address(this)), 10 ether );
        cdpManager.shut(cdp);
        assertEq( sai.balanceOf(address(this)), 0 ether);
        assertEq( skr.balanceOf(address(this)), 20 ether );
    }
    function testGive() public {
        bytes32 cdp = cdpManager.open();
        assertEq(cdpManager.lad(cdp), address(this));

        address ali = address(0x456);
        cdpManager.give(cdp, ali);
        assertEq(cdpManager.lad(cdp), ali);
    }
    function testFailGiveNotLad() public {
        bytes32 cdp = cdpManager.open();
        address ali = address(0x456);
        cdpManager.give(cdp, ali);

        address bob = address(0x789);
        cdpManager.give(cdp, bob);
    }
    function testMold() public {
        (bool result,) = address(mom).call(abi.encodeWithSignature('setCap(uint256)', 0 ether));
        assertTrue(result);

        (result,) = address(mom).call(abi.encodeWithSignature('setCap(uint256)', 5 ether));
        assertTrue(result);

        (result,) = address(mom).call(abi.encodeWithSignature('setAxe(uint256)', ray(2 ether)));
        assertTrue(!result);

        (result,) = address(mom).call(abi.encodeWithSignature('setMat(uint256)', ray(2 ether)));
        assertTrue(result);

        (result,) = address(mom).call(abi.encodeWithSignature('setAxe(uint256)', ray(2 ether)));
        assertTrue(result);

        (result,) = address(mom).call(abi.encodeWithSignature('setMat(uint256)', ray(1 ether)));
        assertTrue(!result);
    }
    function testTune() public {
        assertEq(targetPriceFeed.how(), 0);
        mom.setHow(2 * 10 ** 25);
        assertEq(targetPriceFeed.how(), 2 * 10 ** 25);
    }
    function testPriceFeedSetters() public {
        assertTrue(address(cdpManager.pip()) != address(0x1));
        assertTrue(address(cdpManager.pep()) != address(0x2));
        assertTrue(address(cdpManager.targetPriceFeed()) != address(0x3));

        (bool result,) = address(mom).call(abi.encodeWithSignature('setPip(address)', address(0x1)));
        assertTrue(result);

        (result,) = address(mom).call(abi.encodeWithSignature('setPep(address)', address(0x2)));
        assertTrue(result);

        (result,) = address(mom).call(abi.encodeWithSignature('setTargetPriceFeed(address)', address(0x3)));
        assertTrue(result);

        assertTrue(address(cdpManager.pip()) == address(0x1));
        assertTrue(address(cdpManager.pep()) == address(0x2));
        assertTrue(address(cdpManager.targetPriceFeed()) == address(0x3));
    }
    function testJoinInitial() public {
        assertEq(skr.totalSupply(),     0 ether);
        assertEq(skr.balanceOf(address(this)),   0 ether);
        assertEq(gem.balanceOf(address(this)), 100 ether);
        cdpManager.join(10 ether);
        assertEq(skr.balanceOf(address(this)), 10 ether);
        assertEq(gem.balanceOf(address(this)), 90 ether);
        assertEq(gem.balanceOf(address(cdpManager)),  10 ether);
    }
    function testJoinExit() public {
        assertEq(skr.balanceOf(address(this)), 0 ether);
        assertEq(gem.balanceOf(address(this)), 100 ether);
        cdpManager.join(10 ether);
        assertEq(skr.balanceOf(address(this)), 10 ether);
        assertEq(gem.balanceOf(address(this)), 90 ether);
        assertEq(gem.balanceOf(address(cdpManager)),  10 ether);

        cdpManager.exit(5 ether);
        assertEq(skr.balanceOf(address(this)),  5 ether);
        assertEq(gem.balanceOf(address(this)), 95 ether);
        assertEq(gem.balanceOf(address(cdpManager)),   5 ether);

        cdpManager.join(2 ether);
        assertEq(skr.balanceOf(address(this)),  7 ether);
        assertEq(gem.balanceOf(address(this)), 93 ether);
        assertEq(gem.balanceOf(address(cdpManager)),   7 ether);

        cdpManager.exit(1 ether);
        assertEq(skr.balanceOf(address(this)),  6 ether);
        assertEq(gem.balanceOf(address(this)), 94 ether);
        assertEq(gem.balanceOf(address(cdpManager)),   6 ether);
    }
    function testFailOverDraw() public {
        mom.setMat(ray(1 ether));
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);

        cdpManager.draw(cdp, 11 ether);
    }
    function testFailOverDrawExcess() public {
        mom.setMat(ray(1 ether));
        cdpManager.join(20 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);

        cdpManager.draw(cdp, 11 ether);
    }
    function testDraw() public {
        mom.setMat(ray(1 ether));
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);

        assertEq(sai.balanceOf(address(this)),  0 ether);
        cdpManager.draw(cdp, 10 ether);
        assertEq(sai.balanceOf(address(this)), 10 ether);
    }
    function testWipe() public {
        mom.setMat(ray(1 ether));
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);
        cdpManager.draw(cdp, 10 ether);

        assertEq(sai.balanceOf(address(this)), 10 ether);
        cdpManager.wipe(cdp, 5 ether);
        assertEq(sai.balanceOf(address(this)),  5 ether);
    }
    function testUnsafe() public {
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);
        cdpManager.draw(cdp, 9 ether);

        assertTrue(cdpManager.safe(cdp));
        mark(1 ether / 2);
        assertTrue(!cdpManager.safe(cdp));
    }
    function testBiteUnderParity() public {
        assertEq(uint(cdpManager.axe()), uint(ray(1 ether)));  // 100% collateralisation limit
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);
        cdpManager.draw(cdp, 5 ether);           // 200% collateralisation
        mark(1 ether / 4);                // 50% collateralisation

        assertEq(tap.fog(), uint(0));
        cdpManager.bite(cdp);
        assertEq(tap.fog(), uint(10 ether));
    }
    function testBiteOverParity() public {
        mom.setMat(ray(2 ether));  // require 200% collateralisation
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);

        cdpManager.draw(cdp, 4 ether);  // 250% collateralisation
        assertTrue(cdpManager.safe(cdp));
        mark(1 ether / 2);       // 125% collateralisation
        assertTrue(!cdpManager.safe(cdp));

        assertEq(cdpManager.din(),    4 ether);
        assertEq(cdpManager.tab(cdp), 4 ether);
        assertEq(tap.fog(),    0 ether);
        assertEq(tap.woe(),    0 ether);
        cdpManager.bite(cdp);
        assertEq(cdpManager.din(),    0 ether);
        assertEq(cdpManager.tab(cdp), 0 ether);
        assertEq(tap.fog(),    8 ether);
        assertEq(tap.woe(),    4 ether);

        // cdp should now be safe with 0 sai debt and 2 skr remaining
        uint skr_before = skr.balanceOf(address(this));
        cdpManager.free(cdp, 1 ether);
        assertEq(skr.balanceOf(address(this)) - skr_before, 1 ether);
    }
    function testLock() public {
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();

        assertEq(skr.balanceOf(address(cdpManager)),  0 ether);
        cdpManager.lock(cdp, 10 ether);
        assertEq(skr.balanceOf(address(cdpManager)), 10 ether);
    }
    function testFree() public {
        mom.setMat(ray(2 ether));  // require 200% collateralisation
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);
        cdpManager.draw(cdp, 4 ether);  // 250% collateralisation

        uint skr_before = skr.balanceOf(address(this));
        cdpManager.free(cdp, 2 ether);  // 225%
        assertEq(skr.balanceOf(address(this)) - skr_before, 2 ether);
    }
    function testFailFreeToUnderCollat() public {
        mom.setMat(ray(2 ether));  // require 200% collateralisation
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);
        cdpManager.draw(cdp, 4 ether);  // 250% collateralisation

        cdpManager.free(cdp, 3 ether);  // 175% -- fails
    }
    function testFailDrawOverDebtCeiling() public {
        mom.setCap(4 ether);
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);

        cdpManager.draw(cdp, 5 ether);
    }
    function testDebtCeiling() public {
        mom.setCap(5 ether);
        mom.setMat(ray(2 ether));  // require 200% collat
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);

        cdpManager.draw(cdp, 5 ether);          // 200% collat, full debt ceiling
        mark(1 ether / 2);  // 100% collat

        assertEq(cdpManager.air(), uint(10 ether));
        assertEq(tap.fog(), uint(0 ether));
        cdpManager.bite(cdp);
        assertEq(cdpManager.air(), uint(0 ether));
        assertEq(tap.fog(), uint(10 ether));

        cdpManager.join(10 ether);
        // skr hasn't been diluted yet so still 1:1 skr:gem
        assertEq(skr.balanceOf(address(this)), 10 ether);
    }
}

contract CageTest is SaiTestBase {
    // ensure cage sets the settle prices right
    function cageSetup() public returns (bytes32) {
        mom.setCap(5 ether);            // 5 sai debt ceiling
        mark(1 ether);   // price 1:1 gem:ref
        mom.setMat(ray(2 ether));       // require 200% collat
        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);
        cdpManager.draw(cdp, 5 ether);       // 200% collateralisation

        return cdp;
    }
    function testCageSafeOverCollat() public {
        cageSetup();

        assertEq(top.fix(), 0);
        assertEq(cdpManager.fit(), 0);
        assertEq(tap.woe(), 0);         // no bad debt
        assertEq(cdpManager.pie(), 10 ether);

        cdpManager.join(20 ether);   // give us some more skr
        mark(1 ether);
        top.cage();

        assertEq(cdpManager.din(),      5 ether);  // debt remains in cdpManager
        assertEq(wad(top.fix()), 1 ether);  // sai redeems 1:1 with gem
        assertEq(wad(cdpManager.fit()), 1 ether);  // skr redeems 1:1 with gem just before pushing gem to cdpManager

        assertEq(gem.balanceOf(address(tap)),  5 ether);  // saved for sai
        assertEq(gem.balanceOf(address(cdpManager)), 25 ether);  // saved for skr
    }
    function testCageUnsafeOverCollat() public {
        cageSetup();

        assertEq(top.fix(), 0);
        assertEq(cdpManager.fit(), 0);
        assertEq(cdpManager.per(), ray(1 ether));

        cdpManager.join(20 ether);   // give us some more skr
        uint price = wdiv(3 ether, 4 ether);
        mark(price);
        top.cage();        // 150% collat

        assertEq(top.fix(), rdiv(1 ether, price));  // sai redeems 4:3 with gem
        assertEq(cdpManager.fit(), ray(price));                 // skr redeems 1:1 with gem just before pushing gem to cdpManager

        // gem needed for sai is 5 * 4 / 3
        uint saved = rmul(5 ether, rdiv(WAD, price));
        assertEq(gem.balanceOf(address(tap)),  saved);             // saved for sai
        assertEq(gem.balanceOf(address(cdpManager)),  30 ether - saved);  // saved for skr
    }
    function testCageAtCollat() public {
        cageSetup();

        assertEq(top.fix(), 0);
        assertEq(cdpManager.fit(), 0);
        assertEq(cdpManager.per(), ray(1 ether));

        uint price = wdiv(1 ether, 2 ether);  // 100% collat
        mark(price);
        top.cage();

        assertEq(top.fix(), ray(2 ether));  // sai redeems 1:2 with gem, 1:1 with ref
        assertEq(cdpManager.per(), 0);       // skr redeems 1:0 with gem after cage
    }
    function testCageAtCollatFreeSkr() public {
        cageSetup();

        assertEq(top.fix(), 0);
        assertEq(cdpManager.fit(), 0);
        assertEq(cdpManager.per(), ray(1 ether));

        cdpManager.join(20 ether);   // give us some more skr
        uint price = wdiv(1 ether, 2 ether);  // 100% collat
        mark(price);
        top.cage();

        assertEq(top.fix(), ray(2 ether));  // sai redeems 1:2 with gem, 1:1 with ref
        assertEq(cdpManager.fit(), ray(price));       // skr redeems 1:1 with gem just before pushing gem to cdpManager
    }
    function testCageUnderCollat() public {
        cageSetup();

        assertEq(top.fix(), 0);
        assertEq(cdpManager.fit(), 0);
        assertEq(cdpManager.per(), ray(1 ether));

        uint price = wdiv(1 ether, 4 ether);   // 50% collat
        mark(price);
        top.cage();

        assertEq(2 * sai.totalSupply(), gem.balanceOf(address(tap)));
        assertEq(top.fix(), ray(2 ether));  // sai redeems 1:2 with gem, 2:1 with ref
        assertEq(cdpManager.per(), 0);       // skr redeems 1:0 with gem after cage
    }
    function testCageUnderCollatFreeSkr() public {
        cageSetup();

        assertEq(top.fix(), 0);
        assertEq(cdpManager.fit(), 0);
        assertEq(cdpManager.per(), ray(1 ether));

        cdpManager.join(20 ether);   // give us some more skr
        uint price = wdiv(1 ether, 4 ether);   // 50% collat
        mark(price);
        top.cage();

        assertEq(4 * sai.totalSupply(), gem.balanceOf(address(tap)));
        assertEq(top.fix(), ray(4 ether));                 // sai redeems 1:4 with gem, 1:1 with ref
    }

    function testCageNoSai() public {
        bytes32 cdp = cageSetup();
        cdpManager.wipe(cdp, 5 ether);
        assertEq(sai.totalSupply(), 0);

        top.cage();
        assertEq(top.fix(), ray(1 ether));
    }
    function testMock() public {
        cageSetup();
        top.cage();

        gem.deposit{value: 1000 ether}();
        gem.approve(address(tap), type(uint256).max);
        tap.mock(1000 ether);
        assertEq(sai.balanceOf(address(this)), 1005 ether);
        assertEq(gem.balanceOf(address(tap)),  1005 ether);
    }
    function testMockNoSai() public {
        bytes32 cdp = cageSetup();
        cdpManager.wipe(cdp, 5 ether);
        assertEq(sai.totalSupply(), 0);

        top.cage();

        gem.deposit{value: 1000 ether}();
        gem.approve(address(tap), type(uint256).max);
        tap.mock(1000 ether);
        assertEq(sai.balanceOf(address(this)), 1000 ether);
        assertEq(gem.balanceOf(address(tap)),  1000 ether);
    }

    // ensure cash returns the expected amount
    function testCashSafeOverCollat() public {
        bytes32 cdp = cageSetup();
        mark(1 ether);
        top.cage();

        assertEq(sai.balanceOf(address(this)),  5 ether);
        assertEq(skr.balanceOf(address(this)),  0 ether);
        assertEq(gem.balanceOf(address(this)), 90 ether);
        assertEq(gem.balanceOf(address(cdpManager)),   5 ether);
        assertEq(gem.balanceOf(address(tap)),   5 ether);

        tap.cash(sai.balanceOf(address(this)));
        assertEq(sai.balanceOf(address(this)),   0 ether);
        assertEq(skr.balanceOf(address(this)),   0 ether);
        assertEq(gem.balanceOf(address(this)),  95 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    5 ether);

        assertEq(cdpManager.ink(cdp), 10 ether);
        cdpManager.bite(cdp);
        assertEq(cdpManager.ink(cdp), 5 ether);
        cdpManager.free(cdp, cdpManager.ink(cdp));
        assertEq(skr.balanceOf(address(this)),   5 ether);
        tap.vent();
        top.flow();
        cdpManager.exit(uint256(skr.balanceOf(address(this))));
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);

        assertEq(skr.totalSupply(), 0);
    }
    function testCashSafeOverCollatWithFreeSkr() public {
        bytes32 cdp = cageSetup();
        cdpManager.join(20 ether);   // give us some more skr
        mark(1 ether);
        top.cage();

        assertEq(sai.balanceOf(address(this)),  5 ether);
        assertEq(skr.balanceOf(address(this)), 20 ether);
        assertEq(gem.balanceOf(address(this)), 70 ether);
        assertEq(gem.balanceOf(address(cdpManager)),  25 ether);
        assertEq(gem.balanceOf(address(tap)),   5 ether);

        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp));
        tap.vent();
        top.flow();
        assertEq(skr.balanceOf(address(this)), 25 ether);
        tap.cash(sai.balanceOf(address(this)));
        cdpManager.exit(uint256(skr.balanceOf(address(this))));
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(sai.balanceOf(address(this)),   0 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);

        tap.vent();
        assertEq(sai.totalSupply(), 0);
        assertEq(skr.totalSupply(), 0);
    }
    function testFailCashSafeOverCollatWithFreeSkrExitBeforeBail() public {
        // fails because exit is before bail
        bytes32 cdp = cageSetup();
        cdpManager.join(20 ether);   // give us some more skr
        mark(1 ether);
        top.cage();

        tap.cash(sai.balanceOf(address(this)));
        cdpManager.exit(uint256(skr.balanceOf(address(this))));
        assertEq(skr.balanceOf(address(this)), 0 ether);
        uint256 gemBySAI = 5 ether; // Adding 5 gem from 5 sai
        uint256 gemBySKR = wdiv(wmul(20 ether, 30 ether - gemBySAI), 30 ether);
        assertEq(gem.balanceOf(address(this)), 70 ether + gemBySAI + gemBySKR);

        assertEq(sai.balanceOf(address(this)), 0);
        assertEq(sai.totalSupply(), 0);
        assertEq(sin.totalSupply(), 0);

        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp));
        tap.vent();
        top.flow();
        assertEq(skr.balanceOf(address(this)), 5 ether); // skr retrieved by bail(cdp)

        cdpManager.exit(uint256(skr.balanceOf(address(this))));
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(sai.balanceOf(address(this)),   0 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);
        assertEq(sai.totalSupply(), 0);
        assertEq(sin.totalSupply(), 0);

        assertEq(skr.totalSupply(), 0);
    }
    function testCashUnsafeOverCollat() public {
        bytes32 cdp = cageSetup();
        cdpManager.join(20 ether);   // give us some more skr
        uint price = wdiv(3 ether, 4 ether);
        mark(price);
        top.cage();        // 150% collat

        assertEq(sai.balanceOf(address(this)),  5 ether);
        assertEq(skr.balanceOf(address(this)), 20 ether);
        assertEq(gem.balanceOf(address(this)), 70 ether);

        tap.cash(sai.balanceOf(address(this)));
        assertEq(sai.balanceOf(address(this)),   0 ether);
        assertEq(skr.balanceOf(address(this)),  20 ether);

        uint256 gemBySAI = wdiv(wmul(5 ether, 4 ether), 3 ether);
        uint256 gemBySKR = 0;

        assertEq(gem.balanceOf(address(this)), 70 ether + gemBySAI + gemBySKR);
        assertEq(gem.balanceOf(address(cdpManager)),  30 ether - gemBySAI - gemBySKR);

        // how much gem should be returned?
        // there were 10 gems initially, of which 5 were 100% collat
        // at the cage price, 5 * 4 / 3 are 100% collat,
        // leaving 10 - 5 * 4 / 3 as excess = 3.333
        // this should all be returned
        uint ink = cdpManager.ink(cdp);
        uint tab = cdpManager.tab(cdp);
        uint skrToRecover = sub(ink, wdiv(tab, price));
        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp));

        assertEq(skr.balanceOf(address(this)), 20 ether + skrToRecover);
        assertEq(skr.balanceOf(address(cdpManager)),  0 ether);

        tap.vent();
        top.flow();
        cdpManager.exit(uint256(skr.balanceOf(address(this))));
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);

        tap.vent();
        assertEq(skr.totalSupply(), 0);
        assertEq(sai.totalSupply(), 0);
    }
    function testCashAtCollat() public {
        bytes32 cdp = cageSetup();
        uint price = wdiv(1 ether, 2 ether);  // 100% collat
        mark(price);
        top.cage();

        assertEq(sai.balanceOf(address(this)),  5 ether);
        assertEq(skr.balanceOf(address(this)),  0 ether);
        assertEq(gem.balanceOf(address(this)), 90 ether);
        tap.cash(sai.balanceOf(address(this)));
        assertEq(sai.balanceOf(address(this)),   0 ether);
        assertEq(skr.balanceOf(address(this)),   0 ether);

        uint saved = rmul(5 ether, rdiv(WAD, price));

        assertEq(gem.balanceOf(address(this)),  90 ether + saved);
        assertEq(gem.balanceOf(address(cdpManager)),   10 ether - saved);

        // how much gem should be returned?
        // none :D
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);
        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp));
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);

        tap.vent();
        assertEq(skr.totalSupply(), 0);
        assertEq(sai.totalSupply(), 0);
    }
    function testCashAtCollatFreeSkr() public {
        bytes32 cdp = cageSetup();
        cdpManager.join(20 ether);   // give us some more skr
        uint price = wdiv(1 ether, 2 ether);  // 100% collat
        mark(price);
        top.cage();

        assertEq(sai.balanceOf(address(this)),   5 ether);
        assertEq(skr.balanceOf(address(this)),  20 ether);
        assertEq(gem.balanceOf(address(this)),  70 ether);

        tap.cash(sai.balanceOf(address(this)));
        assertEq(sai.balanceOf(address(this)),   0 ether);

        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp));
        tap.vent();
        top.flow();
        cdpManager.exit(uint256(skr.balanceOf(address(this))));
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);

        assertEq(skr.totalSupply(), 0);
    }
    function testFailCashAtCollatFreeSkrExitBeforeBail() public {
        bytes32 cdp = cageSetup();
        cdpManager.join(20 ether);   // give us some more skr
        uint price = wdiv(1 ether, 2 ether);  // 100% collat
        mark(price);
        top.cage();

        assertEq(sai.balanceOf(address(this)),  5 ether);
        assertEq(skr.balanceOf(address(this)), 20 ether);
        assertEq(gem.balanceOf(address(this)), 70 ether);

        tap.cash(sai.balanceOf(address(this)));
        assertEq(sai.balanceOf(address(this)),   0 ether);
        cdpManager.exit(uint256(skr.balanceOf(address(this))));
        assertEq(skr.balanceOf(address(this)),   0 ether);


        uint gemBySAI = wmul(5 ether, 2 ether);
        uint gemBySKR = wdiv(wmul(20 ether, 30 ether - gemBySAI), 30 ether);

        assertEq(gem.balanceOf(address(this)), 70 ether + gemBySAI + gemBySKR);
        assertEq(gem.balanceOf(address(cdpManager)),  30 ether - gemBySAI - gemBySKR);

        assertEq(sai.totalSupply(), 0);
        assertEq(sin.totalSupply(), 0);

        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp));
        tap.vent();
        cdpManager.exit(uint256(skr.balanceOf(address(this))));

        // CDP did not have skr to free, then the ramaining gem in cdpManager can not be shared as there is not more skr to exit
        assertEq(gem.balanceOf(address(this)), 70 ether + gemBySAI + gemBySKR);
        assertEq(gem.balanceOf(address(cdpManager)),  30 ether - gemBySAI - gemBySKR);

        assertEq(skr.totalSupply(), 0);
    }
    function testCashUnderCollat() public {
        bytes32 cdp = cageSetup();
        uint price = wdiv(1 ether, 4 ether);  // 50% collat
        mark(price);
        top.cage();

        assertEq(sai.balanceOf(address(this)),  5 ether);
        assertEq(skr.balanceOf(address(this)),  0 ether);
        assertEq(gem.balanceOf(address(this)), 90 ether);
        tap.cash(sai.balanceOf(address(this)));
        assertEq(sai.balanceOf(address(this)),   0 ether);
        assertEq(skr.balanceOf(address(this)),   0 ether);

        // get back all 10 gems, which are now only worth 2.5 ref
        // so you've lost 50% on you sai
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);

        // how much gem should be returned?
        // none :D
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);
        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp));
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);

        tap.vent();
        assertEq(skr.totalSupply(), 0);
        assertEq(sai.totalSupply(), 0);
    }
    function testCashUnderCollatFreeSkr() public {
        bytes32 cdp = cageSetup();
        cdpManager.join(20 ether);   // give us some more skr
        uint price = wdiv(1 ether, 4 ether);   // 50% collat
        mark(price);
        top.cage();

        assertEq(sai.balanceOf(address(this)),  5 ether);
        assertEq(gem.balanceOf(address(this)), 70 ether);
        tap.cash(sai.balanceOf(address(this)));
        assertEq(sai.balanceOf(address(this)),  0 ether);
        // returns 20 gems, taken from the free skr,
        // sai is made whole
        assertEq(gem.balanceOf(address(this)), 90 ether);

        assertEq(skr.balanceOf(address(this)),  20 ether);
        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp));

        tap.vent();
        top.flow();
        cdpManager.exit(uint256(skr.balanceOf(address(this))));
        assertEq(skr.balanceOf(address(this)),   0 ether);
        // the skr has taken a 50% loss - 10 gems returned from 20 put in
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(gem.balanceOf(address(cdpManager)),    0 ether);

        assertEq(sai.totalSupply(), 0);
        assertEq(skr.totalSupply(), 0);
    }
    function testCashSafeOverCollatAndMock() public {
        testCashSafeOverCollat();
        gem.approve(address(tap), type(uint256).max);
        tap.mock(5 ether);
        assertEq(sai.balanceOf(address(this)), 5 ether);
        assertEq(gem.balanceOf(address(this)), 95 ether);
        assertEq(gem.balanceOf(address(tap)), 5 ether);
    }
    function testCashSafeOverCollatWithFreeSkrAndMock() public {
        testCashSafeOverCollatWithFreeSkr();
        gem.approve(address(tap), type(uint256).max);
        tap.mock(5 ether);
        assertEq(sai.balanceOf(address(this)), 5 ether);
        assertEq(gem.balanceOf(address(this)), 95 ether);
        assertEq(gem.balanceOf(address(tap)), 5 ether);
    }
    function testFailCashSafeOverCollatWithFreeSkrExitBeforeBailAndMock() public {
        testFailCashSafeOverCollatWithFreeSkrExitBeforeBail();
        gem.approve(address(tap), type(uint256).max);
        tap.mock(5 ether);
        assertEq(sai.balanceOf(address(this)), 5 ether);
        assertEq(gem.balanceOf(address(this)), 95 ether);
        assertEq(gem.balanceOf(address(tap)), 5 ether);
    }

    function testThreeCDPsOverCollat() public {
        bytes32 cdp = cageSetup();
        cdpManager.join(90 ether);   // give us some more skr
        bytes32 cdp2 = cdpManager.open(); // open a new cdp
        cdpManager.lock(cdp2, 20 ether); // lock collateral but not draw DAI
        bytes32 cdp3 = cdpManager.open(); // open a new cdp
        cdpManager.lock(cdp3, 20 ether); // lock collateral but not draw DAI

        assertEq(gem.balanceOf(address(tap)), 0);
        assertEq(gem.balanceOf(address(cdpManager)), 100 ether);
        assertEq(gem.balanceOf(address(this)), 0);
        assertEq(skr.balanceOf(address(this)), 50 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 50 ether); // locked skr

        uint256 price = 1 ether;
        mark(price);
        top.cage();

        assertEq(gem.balanceOf(address(tap)), 5 ether); // Needed to payout 5 sai
        assertEq(gem.balanceOf(address(cdpManager)), 95 ether);

        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp)); // 5 skr recovered, and 5 skr burnt

        assertEq(skr.balanceOf(address(this)), 55 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 40 ether); // locked skr

        cdpManager.bite(cdp2);
        cdpManager.free(cdp2, cdpManager.ink(cdp2)); // 20 skr recovered

        assertEq(skr.balanceOf(address(this)), 75 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 20 ether); // locked skr

        cdpManager.bite(cdp3);
        cdpManager.free(cdp3, cdpManager.ink(cdp3)); // 20 skr recovered

        assertEq(skr.balanceOf(address(this)), 95 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 0); // locked skr

        tap.cash(sai.balanceOf(address(this)));

        assertEq(sai.balanceOf(address(this)), 0);
        assertEq(gem.balanceOf(address(this)), 5 ether);

        tap.vent();
        top.flow();
        cdpManager.exit(uint256(skr.balanceOf(address(this)))); // exit 95 skr at price 95/95

        assertEq(gem.balanceOf(address(cdpManager)), 0);
        assertEq(gem.balanceOf(address(tap)), 0);
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(skr.totalSupply(), 0);
    }
    function testThreeCDPsAtCollat() public {
        bytes32 cdp = cageSetup();
        cdpManager.join(90 ether);   // give us some more skr
        bytes32 cdp2 = cdpManager.open(); // open a new cdp
        cdpManager.lock(cdp2, 20 ether); // lock collateral but not draw DAI
        bytes32 cdp3 = cdpManager.open(); // open a new cdp
        cdpManager.lock(cdp3, 20 ether); // lock collateral but not draw DAI

        assertEq(gem.balanceOf(address(tap)), 0);
        assertEq(gem.balanceOf(address(cdpManager)), 100 ether);
        assertEq(gem.balanceOf(address(this)), 0);
        assertEq(skr.balanceOf(address(this)), 50 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 50 ether); // locked skr

        uint price = wdiv(1 ether, 2 ether);
        mark(price);
        top.cage();

        assertEq(gem.balanceOf(address(tap)), 10 ether); // Needed to payout 10 sai
        assertEq(gem.balanceOf(address(cdpManager)), 90 ether);

        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp)); // 10 skr burnt

        assertEq(skr.balanceOf(address(this)), 50 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 40 ether); // locked skr

        cdpManager.bite(cdp2);
        cdpManager.free(cdp2, cdpManager.ink(cdp2)); // 20 skr recovered

        assertEq(skr.balanceOf(address(this)), 70 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 20 ether); // locked skr

        cdpManager.bite(cdp3);
        cdpManager.free(cdp3, cdpManager.ink(cdp3)); // 20 skr recovered

        assertEq(skr.balanceOf(address(this)), 90 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 0); // locked skr

        tap.cash(sai.balanceOf(address(this)));

        assertEq(sai.balanceOf(address(this)), 0);
        assertEq(gem.balanceOf(address(this)), 10 ether);

        tap.vent();
        top.flow();
        cdpManager.exit(uint256(skr.balanceOf(address(this)))); // exit 90 skr at price 90/90

        assertEq(gem.balanceOf(address(cdpManager)), 0);
        assertEq(gem.balanceOf(address(tap)), 0);
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(skr.totalSupply(), 0);
    }
    function testThreeCDPsUnderCollat() public {
        bytes32 cdp = cageSetup();
        cdpManager.join(90 ether);   // give us some more skr
        bytes32 cdp2 = cdpManager.open(); // open a new cdp
        cdpManager.lock(cdp2, 20 ether); // lock collateral but not draw DAI
        bytes32 cdp3 = cdpManager.open(); // open a new cdp
        cdpManager.lock(cdp3, 20 ether); // lock collateral but not draw DAI

        assertEq(gem.balanceOf(address(tap)), 0);
        assertEq(gem.balanceOf(address(cdpManager)), 100 ether);
        assertEq(gem.balanceOf(address(this)), 0);
        assertEq(skr.balanceOf(address(this)), 50 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 50 ether); // locked skr

        uint price = wdiv(1 ether, 4 ether);
        mark(price);
        top.cage();

        assertEq(gem.balanceOf(address(tap)), 20 ether); // Needed to payout 5 sai
        assertEq(gem.balanceOf(address(cdpManager)), 80 ether);

        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp)); // No skr is retrieved as the cdp doesn't even cover the debt. 10 locked skr in cdp are burnt from cdpManager

        assertEq(skr.balanceOf(address(this)), 50 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 40 ether); // locked skr

        cdpManager.bite(cdp2);
        cdpManager.free(cdp2, cdpManager.ink(cdp2)); // 20 skr recovered

        assertEq(skr.balanceOf(address(this)), 70 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 20 ether); // locked skr

        cdpManager.bite(cdp3);
        cdpManager.free(cdp3, cdpManager.ink(cdp3)); // 20 skr recovered

        assertEq(skr.balanceOf(address(this)), 90 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 0); // locked skr

        tap.cash(sai.balanceOf(address(this)));

        assertEq(sai.balanceOf(address(this)), 0);
        assertEq(gem.balanceOf(address(this)), 20 ether);

        tap.vent();
        top.flow();
        cdpManager.exit(uint256(skr.balanceOf(address(this)))); // exit 90 skr at price 80/90

        assertEq(gem.balanceOf(address(cdpManager)), 0);
        assertEq(gem.balanceOf(address(tap)), 0);
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(skr.totalSupply(), 0);
    }
    function testThreeCDPsSKRZeroValue() public {
        bytes32 cdp = cageSetup();
        cdpManager.join(90 ether);   // give us some more skr
        bytes32 cdp2 = cdpManager.open(); // open a new cdp
        cdpManager.lock(cdp2, 20 ether); // lock collateral but not draw DAI
        bytes32 cdp3 = cdpManager.open(); // open a new cdp
        cdpManager.lock(cdp3, 20 ether); // lock collateral but not draw DAI

        assertEq(gem.balanceOf(address(tap)), 0);
        assertEq(gem.balanceOf(address(cdpManager)), 100 ether);
        assertEq(gem.balanceOf(address(this)), 0);
        assertEq(skr.balanceOf(address(this)), 50 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 50 ether); // locked skr

        uint price = wdiv(1 ether, 20 ether);
        mark(price);
        top.cage();

        assertEq(gem.balanceOf(address(tap)), 100 ether); // Needed to payout 5 sai
        assertEq(gem.balanceOf(address(cdpManager)), 0 ether);

        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp)); // No skr is retrieved as the cdp doesn't even cover the debt. 10 locked skr in cdp are burnt from cdpManager

        assertEq(skr.balanceOf(address(this)), 50 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 40 ether); // locked skr

        cdpManager.bite(cdp2);
        cdpManager.free(cdp2, cdpManager.ink(cdp2)); // 20 skr recovered

        assertEq(skr.balanceOf(address(this)), 70 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 20 ether); // locked skr

        cdpManager.bite(cdp3);
        cdpManager.free(cdp3, cdpManager.ink(cdp3)); // 20 skr recovered

        assertEq(skr.balanceOf(address(this)), 90 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 0); // locked skr

        tap.cash(sai.balanceOf(address(this)));

        assertEq(sai.balanceOf(address(this)), 0);
        assertEq(gem.balanceOf(address(this)), 100 ether);

        tap.vent();
        top.flow();
        cdpManager.exit(uint256(skr.balanceOf(address(this)))); // exit 90 skr at price 0/90

        assertEq(gem.balanceOf(address(cdpManager)), 0);
        assertEq(gem.balanceOf(address(tap)), 0);
        assertEq(gem.balanceOf(address(this)), 100 ether);
        assertEq(skr.totalSupply(), 0);
    }

    function testPeriodicFixValue() public {
        cageSetup();

        assertEq(gem.balanceOf(address(tap)), 0);
        assertEq(gem.balanceOf(address(cdpManager)), 10 ether);
        assertEq(gem.balanceOf(address(this)), 90 ether);
        assertEq(skr.balanceOf(address(this)), 0 ether); // free skr
        assertEq(skr.balanceOf(address(cdpManager)), 10 ether); // locked skr

        FakePerson person = new FakePerson(tap);
        sai.transfer(address(person), 2.5 ether); // Transfer half of SAI balance to the other user

        uint price = rdiv(9 ether, 8 ether);
        mark(price);
        top.cage();

        assertEq(gem.balanceOf(address(tap)), rmul(5 ether, top.fix())); // Needed to payout 5 sai
        assertEq(gem.balanceOf(address(cdpManager)), sub(10 ether, rmul(5 ether, top.fix())));

        tap.cash(sai.balanceOf(address(this)));

        assertEq(sai.balanceOf(address(this)),     0 ether);
        assertEq(sai.balanceOf(address(person)), 2.5 ether);
        assertEq(gem.balanceOf(address(this)), add(90 ether, rmul(2.5 ether, top.fix())));

        person.cash();
    }

    function testCageExitAfterPeriod() public {
        bytes32 cdp = cageSetup();
        mom.setMat(ray(1 ether));  // 100% collat limit
        cdpManager.free(cdp, 5 ether);  // 100% collat

        assertEq(uint(top.caged()), 0);
        top.cage();
        assertEq(uint(top.caged()), targetPriceFeed.era());

        // exit fails because ice != 0 && fog !=0 and not enough time passed
        (bool result,) = address(cdpManager).call(abi.encodeWithSignature('exit(uint256)', 5 ether));
        assertTrue(!result);

        top.setCooldown(1 days);
        warp(1 days);

        (result,) = address(cdpManager).call(abi.encodeWithSignature('exit(uint256)', 5 ether));
        assertTrue(!result);

        warp(1 seconds);
        top.flow();
        assertEq(skr.balanceOf(address(this)), 5 ether);
        assertEq(gem.balanceOf(address(this)), 90 ether);

        (result,) = address(cdpManager).call(abi.encodeWithSignature('exit(uint256)', 4 ether));
        assertTrue(result);
        assertEq(skr.balanceOf(address(this)), 1 ether);
        // n.b. we don't get back 4 as there is still skr in the cdp
        assertEq(gem.balanceOf(address(this)), 92 ether);

        // now we can cash in our sai
        assertEq(sai.balanceOf(address(this)), 5 ether);
        tap.cash(sai.balanceOf(address(this)));
        assertEq(sai.balanceOf(address(this)), 0 ether);
        assertEq(gem.balanceOf(address(this)), 97 ether);

        // the remaining gem can be claimed only if the cdp skr is burned
        assertEq(cdpManager.air(), 5 ether);
        assertEq(tap.fog(), 0 ether);
        assertEq(cdpManager.din(), 5 ether);
        assertEq(tap.woe(), 0 ether);
        cdpManager.bite(cdp);
        assertEq(cdpManager.air(), 0 ether);
        assertEq(tap.fog(), 5 ether);
        assertEq(cdpManager.din(), 0 ether);
        assertEq(tap.woe(), 5 ether);

        tap.vent();
        assertEq(tap.fog(), 0 ether);

        // now this remaining 1 skr will claim all the remaining 3 ether.
        // this is why exiting early is bad if you want to maximise returns.
        // if we had exited with all the skr earlier, there would be 2.5 gem
        // trapped in the cdpManager.
        cdpManager.exit(1 ether);
        assertEq(skr.balanceOf(address(this)),   0 ether);
        assertEq(gem.balanceOf(address(this)), 100 ether);
    }

    function testShutEmptyCDP() public {
        bytes32 cdp = cdpManager.open();
        (address lad,,,) = cdpManager.cdps(cdp);
        assertEq(lad, address(this));
        cdpManager.shut(cdp);
        (lad,,,) = cdpManager.cdps(cdp);
        assertEq(lad, address(0));
    }
}

contract LiquidationTest is SaiTestBase {
    function liq(bytes32 cdp) internal returns (uint256) {
        // compute the liquidation price of a cdp
        uint jam = rmul(cdpManager.ink(cdp), cdpManager.per());  // this many eth
        uint con = rmul(cdpManager.tab(cdp), targetPriceFeed.targetPrice());  // this much ref debt
        uint min = rmul(con, cdpManager.mat());        // minimum ref debt
        return wdiv(min, jam);
    }
    function testLiq() public {
        mom.setCap(100 ether);
        mark(2 ether);

        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);
        cdpManager.draw(cdp, 10 ether);        // 200% collateralisation

        mom.setMat(ray(1 ether));         // require 100% collateralisation
        assertEq(liq(cdp), 1 ether);

        mom.setMat(ray(3 ether / 2));     // require 150% collateralisation
        assertEq(liq(cdp), wdiv(3 ether, 2 ether));

        mark(6 ether);
        assertEq(liq(cdp), wdiv(3 ether, 2 ether));

        cdpManager.draw(cdp, 30 ether);
        assertEq(liq(cdp), 6 ether);

        cdpManager.join(10 ether);
        assertEq(liq(cdp), 6 ether);

        cdpManager.lock(cdp, 10 ether);  // now 40 drawn on 20 gem == 120 ref
        assertEq(liq(cdp), 3 ether);
    }
    function collat(bytes32 cdp) internal returns (uint256) {
        // compute the collateralised fraction of a cdp
        uint pro = rmul(cdpManager.ink(cdp), cdpManager.tag());
        uint con = rmul(cdpManager.tab(cdp), targetPriceFeed.targetPrice());
        return wdiv(pro, con);
    }
    function testCollat() public {
        mom.setCap(100 ether);
        mark(2 ether);

        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);
        cdpManager.draw(cdp, 10 ether);

        assertEq(collat(cdp), 2 ether);  // 200%

        mark(4 ether);
        assertEq(collat(cdp), 4 ether);  // 400%

        cdpManager.draw(cdp, 15 ether);
        assertEq(collat(cdp), wdiv(8 ether, 5 ether));  // 160%

        mark(5 ether);
        cdpManager.free(cdp, 5 ether);
        assertEq(collat(cdp), 1 ether);  // 100%

        mark(4 ether);
        assertEq(collat(cdp), wdiv(4 ether, 5 ether));  // 80%

        cdpManager.wipe(cdp, 9 ether);
        assertEq(collat(cdp), wdiv(5 ether, 4 ether));  // 125%
    }

    function testBustMint() public {
        mom.setCap(100 ether);
        mom.setMat(ray(wdiv(3 ether, 2 ether)));  // 150% liq limit
        mark(2 ether);

        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);

        mark(3 ether);
        cdpManager.draw(cdp, 16 ether);  // 125% collat
        mark(2 ether);

        assertTrue(!cdpManager.safe(cdp));
        cdpManager.bite(cdp);
        // 20 ref of gem on 16 ref of sai
        // 125%
        // 100% = 16ref of gem == 8 gem
        assertEq(tap.fog(), 8 ether);

        // 8 skr for sale
        assertEq(cdpManager.per(), ray(1 ether));

        // get 2 skr, pay 4 sai (25% of the debt)
        uint sai_before = sai.balanceOf(address(this));
        uint skr_before = skr.balanceOf(address(this));
        assertEq(sai_before, 16 ether);
        tap.bust(2 ether);
        uint sai_after = sai.balanceOf(address(this));
        uint skr_after = skr.balanceOf(address(this));
        assertEq(sai_before - sai_after, 4 ether);
        assertEq(skr_after - skr_before, 2 ether);

        // price drop. now remaining 6 skr cannot cover bad debt (12 sai)
        mark(1 ether);

        // get 6 skr, pay 6 sai
        tap.bust(6 ether);
        // no more skr remaining to sell
        assertEq(tap.fog(), 0);
        // but skr supply unchanged
        assertEq(skr.totalSupply(), 10 ether);

        // now skr will be minted
        tap.bust(2 ether);
        assertEq(skr.totalSupply(), 12 ether);
    }
    function testBustNoMint() public {
        mom.setCap(1000 ether);
        mom.setMat(ray(2 ether));    // 200% liq limit
        mom.setAxe(ray(1.5 ether));  // 150% liq penalty
        mark(20 ether);

        cdpManager.join(10 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 10 ether);
        cdpManager.draw(cdp, 100 ether);  // 200 % collat

        mark(15 ether);
        cdpManager.bite(cdp);

        // nothing remains in the cdp
        assertEq(cdpManager.tab(cdp), 0);
        assertEq(cdpManager.ink(cdp), 0);

        // all collateral is now fog
        assertEq(tap.fog(), 10 ether);
        assertEq(tap.woe(), 100 ether);

        // the fog is worth 150 sai and the woe is worth 100 sai.
        // If all the fog is sold, there will be a sai surplus.

        // get some more sai to buy with
        cdpManager.join(10 ether);
        bytes32 mug = cdpManager.open();
        cdpManager.lock(mug, 10 ether);
        cdpManager.draw(mug, 50 ether);

        tap.bust(10 ether);
        assertEq(sai.balanceOf(address(this)), 0 ether);
        assertEq(skr.balanceOf(address(this)), 10 ether);
        assertEq(tap.fog(), 0 ether);
        assertEq(tap.woe(), 0 ether);
        assertEq(tap.joy(), 50 ether);

        // joy is available through boom
        assertEq(tap.bid(1 ether), 15 ether);
        tap.boom(2 ether);
        assertEq(sai.balanceOf(address(this)), 30 ether);
        assertEq(skr.balanceOf(address(this)),  8 ether);
        assertEq(tap.fog(), 0 ether);
        assertEq(tap.woe(), 0 ether);
        assertEq(tap.joy(), 20 ether);
    }
}

contract TapTest is SaiTestBase {
    function testTapSetup() public {
        assertEq(sai.balanceOf(address(tap)), tap.joy());
        assertEq(sin.balanceOf(address(tap)), tap.woe());
        assertEq(skr.balanceOf(address(tap)), tap.fog());

        assertEq(tap.joy(), 0);
        assertEq(tap.woe(), 0);
        assertEq(tap.fog(), 0);

        sai.mint(address(tap), 3);
        sin.mint(address(tap), 4);
        skr.mint(address(tap), 5);

        assertEq(tap.joy(), 3);
        assertEq(tap.woe(), 4);
        assertEq(tap.fog(), 5);
    }
    // boom (flap) is surplus sale (sai for skr->burn)
    function testTapBoom() public {
        sai.mint(address(tap), 50 ether);
        cdpManager.join(60 ether);

        assertEq(sai.balanceOf(address(this)),  0 ether);
        assertEq(skr.balanceOf(address(this)), 60 ether);
        tap.boom(50 ether);
        assertEq(sai.balanceOf(address(this)), 50 ether);
        assertEq(skr.balanceOf(address(this)), 10 ether);
        assertEq(tap.joy(), 0);
    }
    function testFailTapBoomOverJoy() public {
        sai.mint(address(tap), 50 ether);
        cdpManager.join(60 ether);
        tap.boom(51 ether);
    }
    function testTapBoomHeals() public {
        sai.mint(address(tap), 60 ether);
        sin.mint(address(tap), 50 ether);
        cdpManager.join(10 ether);

        tap.boom(0 ether);
        assertEq(tap.joy(), 10 ether);
    }
    function testFailTapBoomNetWoe() public {
        sai.mint(address(tap), 50 ether);
        sin.mint(address(tap), 60 ether);
        cdpManager.join(10 ether);
        tap.boom(1 ether);
    }
    function testTapBoomBurnsSkr() public {
        sai.mint(address(tap), 50 ether);
        cdpManager.join(60 ether);

        assertEq(skr.totalSupply(), 60 ether);
        tap.boom(20 ether);
        assertEq(skr.totalSupply(), 40 ether);
    }
    function testTapBoomIncreasesPer() public {
        sai.mint(address(tap), 50 ether);
        cdpManager.join(60 ether);

        assertEq(cdpManager.per(), ray(1 ether));
        tap.boom(30 ether);
        assertEq(cdpManager.per(), ray(2 ether));
    }
    function testTapBoomMarkDep() public {
        sai.mint(address(tap), 50 ether);
        cdpManager.join(50 ether);

        mark(2 ether);
        tap.boom(10 ether);
        assertEq(sai.balanceOf(address(this)), 20 ether);
        assertEq(sai.balanceOf(address(tap)),  30 ether);
        assertEq(skr.balanceOf(address(this)), 40 ether);
    }
    function testTapBoomPerDep() public {
        sai.mint(address(tap), 50 ether);
        cdpManager.join(50 ether);

        assertEq(cdpManager.per(), ray(1 ether));
        skr.mint(50 ether);  // halves per
        assertEq(cdpManager.per(), ray(.5 ether));

        tap.boom(10 ether);
        assertEq(sai.balanceOf(address(this)),  5 ether);
        assertEq(sai.balanceOf(address(tap)),  45 ether);
        assertEq(skr.balanceOf(address(this)), 90 ether);
    }
    // flip is collateral sale (skr for sai)
    function testTapBustFlip() public {
        sai.mint(50 ether);
        cdpManager.join(50 ether);
        skr.push(address(tap), 50 ether);
        assertEq(tap.fog(), 50 ether);

        assertEq(skr.balanceOf(address(this)),  0 ether);
        assertEq(sai.balanceOf(address(this)), 50 ether);
        tap.bust(30 ether);
        assertEq(skr.balanceOf(address(this)), 30 ether);
        assertEq(sai.balanceOf(address(this)), 20 ether);
    }
    function testFailTapBustFlipOverFog() public { // FAIL
        sai.mint(50 ether);
        cdpManager.join(50 ether);
        skr.push(address(tap), 50 ether);

        tap.bust(51 ether);
    }
    function testTapBustFlipHealsNetJoy() public {
        sai.mint(address(tap), 10 ether);
        sin.mint(address(tap), 20 ether);
        cdpManager.join(50 ether);
        skr.push(address(tap), 50 ether);

        sai.mint(15 ether);
        tap.bust(15 ether);
        assertEq(tap.joy(), 5 ether);
        assertEq(tap.woe(), 0 ether);
    }
    function testTapBustFlipHealsNetWoe() public {
        sai.mint(address(tap), 10 ether);
        sin.mint(address(tap), 20 ether);
        cdpManager.join(50 ether);
        skr.push(address(tap), 50 ether);

        sai.mint(5 ether);
        tap.bust(5 ether);
        assertEq(tap.joy(), 0 ether);
        assertEq(tap.woe(), 5 ether);
    }
    // flop is debt sale (woe->skr for sai)
    function testTapBustFlop() public {
        cdpManager.join(50 ether);  // avoid per=1 init case
        sai.mint(100 ether);
        sin.mint(address(tap), 50 ether);
        assertEq(tap.woe(), 50 ether);

        assertEq(skr.balanceOf(address(this)),  50 ether);
        assertEq(sai.balanceOf(address(this)), 100 ether);
        tap.bust(50 ether);
        assertEq(skr.balanceOf(address(this)), 100 ether);
        assertEq(sai.balanceOf(address(this)),  75 ether);
    }
    function testFailTapBustFlopNetJoy() public {
        cdpManager.join(50 ether);  // avoid per=1 init case
        sai.mint(100 ether);
        sin.mint(address(tap), 50 ether);
        sai.mint(address(tap), 100 ether);

        tap.bust(1);  // anything but zero should fail
    }
    function testTapBustFlopMintsSkr() public {
        cdpManager.join(50 ether);  // avoid per=1 init case
        sai.mint(100 ether);
        sin.mint(address(tap), 50 ether);

        assertEq(skr.totalSupply(),  50 ether);
        tap.bust(20 ether);
        assertEq(skr.totalSupply(),  70 ether);
    }
    function testTapBustFlopDecreasesPer() public {
        cdpManager.join(50 ether);  // avoid per=1 init case
        sai.mint(100 ether);
        sin.mint(address(tap), 50 ether);

        assertEq(cdpManager.per(), ray(1 ether));
        tap.bust(50 ether);
        assertEq(cdpManager.per(), ray(.5 ether));
    }

    function testTapBustAsk() public {
        cdpManager.join(50 ether);
        assertEq(tap.ask(50 ether), 50 ether);

        skr.mint(50 ether);
        assertEq(tap.ask(50 ether), 25 ether);

        skr.mint(100 ether);
        assertEq(tap.ask(50 ether), 12.5 ether);

        skr.burn(175 ether);
        assertEq(tap.ask(50 ether), 100 ether);

        skr.mint(25 ether);
        assertEq(tap.ask(50 ether), 50 ether);

        skr.mint(10 ether);
        // per = 5 / 6
        assertEq(tap.ask(60 ether), 50 ether);

        skr.mint(30 ether);
        // per = 5 / 9
        assertEq(tap.ask(90 ether), 50 ether);

        skr.mint(10 ether);
        // per = 1 / 2
        assertEq(tap.ask(100 ether), 50 ether);
    }
    // flipflop is debt sale when collateral present
    function testTapBustFlipFlopRounding() public {
        cdpManager.join(50 ether);  // avoid per=1 init case
        sai.mint(100 ether);
        sin.mint(address(tap), 100 ether);
        skr.push(address(tap),  50 ether);
        assertEq(tap.joy(),   0 ether);
        assertEq(tap.woe(), 100 ether);
        assertEq(tap.fog(),  50 ether);

        assertEq(skr.balanceOf(address(this)),   0 ether);
        assertEq(sai.balanceOf(address(this)), 100 ether);
        assertEq(skr.totalSupply(),    50 ether);

        assertEq(cdpManager.per(), ray(1 ether));
        assertEq(tap.s2s(), ray(1 ether));
        assertEq(cdpManager.tag(), ray(1 ether));
        assertEq(tap.ask(60 ether), 60 ether);
        tap.bust(60 ether);
        assertEq(cdpManager.per(), rdiv(5, 6));
        assertEq(tap.s2s(), rdiv(5, 6));
        assertEq(cdpManager.tag(), rdiv(5, 6));
        // non ray prices would give small rounding error because wad math
        assertEq(tap.ask(60 ether), 50 ether);
        assertEq(skr.totalSupply(),    60 ether);
        assertEq(tap.fog(),             0 ether);
        assertEq(skr.balanceOf(address(this)),  60 ether);
        assertEq(sai.balanceOf(address(this)),  50 ether);
    }
    function testTapBustFlipFlop() public {
        cdpManager.join(50 ether);  // avoid per=1 init case
        sai.mint(100 ether);
        sin.mint(address(tap), 100 ether);
        skr.push(address(tap),  50 ether);
        assertEq(tap.joy(),   0 ether);
        assertEq(tap.woe(), 100 ether);
        assertEq(tap.fog(),  50 ether);

        assertEq(skr.balanceOf(address(this)),   0 ether);
        assertEq(sai.balanceOf(address(this)), 100 ether);
        assertEq(skr.totalSupply(),    50 ether);
        assertEq(cdpManager.per(), ray(1 ether));
        tap.bust(80 ether);
        assertEq(cdpManager.per(), rdiv(5, 8));
        assertEq(skr.totalSupply(),    80 ether);
        assertEq(tap.fog(),             0 ether);
        assertEq(skr.balanceOf(address(this)),  80 ether);
        assertEq(sai.balanceOf(address(this)),  50 ether);  // expected 50, actual 50 ether + 2???!!!
    }
}

contract TaxTest is SaiTestBase {
    function testEraInit() public {
        assertEq(uint(targetPriceFeed.era()), block.timestamp);
    }
    function testEraWarp() public {
        warp(20);
        assertEq(uint(targetPriceFeed.era()), block.timestamp + 20);
    }
    function taxSetup() public returns (bytes32 cdp) {
        mark(10 ether);
        gem.deposit{value: 1000 ether}();

        mom.setCap(1000 ether);
        mom.setTax(1000000564701133626865910626);  // 5% / day
        cdp = cdpManager.open();
        cdpManager.join(100 ether);
        cdpManager.lock(cdp, 100 ether);
        cdpManager.draw(cdp, 100 ether);
    }
    function testTaxEra() public {
        bytes32 cdp = taxSetup();
        assertEq(cdpManager.tab(cdp), 100 ether);
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 105 ether);
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 110.25 ether);
    }
    // rum doesn't change on drip
    function testTaxRum() public {
        taxSetup();
        assertEq(cdpManager.rum(),    100 ether);
        warp(1 days);
        cdpManager.drip();
        assertEq(cdpManager.rum(),    100 ether);
    }
    // din increases on drip
    function testTaxDin() public {
        taxSetup();
        assertEq(cdpManager.din(),    100 ether);
        warp(1 days);
        cdpManager.drip();
        assertEq(cdpManager.din(),    105 ether);
    }
    // Tax accumulates as sai surplus, and CDP debt
    function testTaxJoy() public {
        bytes32 cdp = taxSetup();
        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.din(),    100 ether);
        assertEq(tap.joy(),      0 ether);
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 105 ether);
        assertEq(cdpManager.din(),    105 ether);
        assertEq(tap.joy(),      5 ether);
    }
    function testTaxJoy2() public {
        bytes32 cdp = taxSetup();
        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.din(),    100 ether);
        assertEq(tap.joy(),      0 ether);
        warp(1 days);
        cdpManager.drip();
        assertEq(cdpManager.tab(cdp), 105 ether);
        assertEq(cdpManager.din(),    105 ether);
        assertEq(tap.joy(),      5 ether);
        // now ensure din != rum
        cdpManager.wipe(cdp, 5 ether);
        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.din(),    100 ether);
        assertEq(tap.joy(),      5 ether);
        warp(1 days);
        cdpManager.drip();
        assertEq(cdpManager.tab(cdp), 105 ether);
        assertEq(cdpManager.din(),    105 ether);
        assertEq(tap.joy(),     10 ether);
    }
    function testTaxJoy3() public {
        bytes32 cdp = taxSetup();
        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.din(),    100 ether);
        assertEq(tap.joy(),      0 ether);
        warp(1 days);
        cdpManager.drip();
        assertEq(cdpManager.tab(cdp), 105 ether);
        assertEq(cdpManager.din(),    105 ether);
        assertEq(tap.joy(),      5 ether);
        // now ensure rum changes
        cdpManager.wipe(cdp, 5 ether);
        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.din(),    100 ether);
        assertEq(tap.joy(),      5 ether);
        warp(1 days);
        cdpManager.drip();
        assertEq(cdpManager.tab(cdp), 105 ether);
        assertEq(cdpManager.din(),    105 ether);
        assertEq(tap.joy(),     10 ether);
        // and ensure the last rum != din either
        cdpManager.wipe(cdp, 5 ether);
        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.din(),    100 ether);
        assertEq(tap.joy(),     10 ether);
        warp(1 days);
        cdpManager.drip();
        assertEq(cdpManager.tab(cdp), 105 ether);
        assertEq(cdpManager.din(),    105 ether);
        assertEq(tap.joy(),     15 ether);
    }
    function testTaxDraw() public {
        bytes32 cdp = taxSetup();
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 105 ether);
        cdpManager.draw(cdp, 100 ether);
        assertEq(cdpManager.tab(cdp), 205 ether);
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 215.25 ether);
    }
    function testTaxWipe() public {
        bytes32 cdp = taxSetup();
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 105 ether);
        cdpManager.wipe(cdp, 50 ether);
        assertEq(cdpManager.tab(cdp), 55 ether);
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 57.75 ether);
    }
    // collected fees are available through boom
    function testTaxBoom() public {
        taxSetup();
        warp(1 days);
        // should have 5 sai available == 0.5 skr
        cdpManager.join(0.5 ether);  // get some unlocked skr

        assertEq(skr.totalSupply(),   100.5 ether);
        assertEq(sai.balanceOf(address(tap)),    0 ether);
        assertEq(sin.balanceOf(address(tap)),    0 ether);
        assertEq(sai.balanceOf(address(this)), 100 ether);
        cdpManager.drip();
        assertEq(sai.balanceOf(address(tap)),    5 ether);
        tap.boom(0.5 ether);
        assertEq(skr.totalSupply(),   100 ether);
        assertEq(sai.balanceOf(address(tap)),    0 ether);
        assertEq(sin.balanceOf(address(tap)),    0 ether);
        assertEq(sai.balanceOf(address(this)), 105 ether);
    }
    // Tax can flip a cdp to unsafe
    function testTaxSafe() public {
        bytes32 cdp = taxSetup();
        mark(1 ether);
        assertTrue(cdpManager.safe(cdp));
        warp(1 days);
        assertTrue(!cdpManager.safe(cdp));
    }
    function testTaxBite() public {
        bytes32 cdp = taxSetup();
        mark(1 ether);
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 105 ether);
        cdpManager.bite(cdp);
        assertEq(cdpManager.tab(cdp),   0 ether);
        assertEq(tap.woe(),    105 ether);
    }
    function testTaxBiteRounding() public {
        bytes32 cdp = taxSetup();
        mark(1 ether);
        mom.setMat(ray(1.5 ether));
        mom.setAxe(ray(1.4 ether));
        mom.setTax(ray(1.000000001547126 ether));
        // log_named_uint('tab', cdpManager.tab(cdp));
        // log_named_uint('sin', cdpManager.din());
        for (uint i=0; i<=50; i++) {
            warp(10);
            // log_named_uint('tab', cdpManager.tab(cdp));
            // log_named_uint('sin', cdpManager.din());
        }
        uint256 debtAfterWarp = rmul(100 ether, rpow(cdpManager.tax(), 510));
        assertEq(cdpManager.tab(cdp), debtAfterWarp);
        cdpManager.bite(cdp);
        assertEq(cdpManager.tab(cdp), 0 ether);
        assertEq(tap.woe(), rmul(100 ether, rpow(cdpManager.tax(), 510)));
    }
    function testTaxBail() public {
        bytes32 cdp = taxSetup();
        warp(1 days);
        cdpManager.drip();
        mark(10 ether);
        top.cage();

        warp(1 days);  // should have no effect
        cdpManager.drip();

        assertEq(skr.balanceOf(address(this)),  0 ether);
        assertEq(skr.balanceOf(address(cdpManager)), 100 ether);
        cdpManager.bite(cdp);
        cdpManager.free(cdp, cdpManager.ink(cdp));
        assertEq(skr.balanceOf(address(this)), 89.5 ether);
        assertEq(skr.balanceOf(address(cdpManager)),     0 ether);

        assertEq(sai.balanceOf(address(this)),  100 ether);
        assertEq(gem.balanceOf(address(this)), 1000 ether);
        tap.cash(sai.balanceOf(address(this)));
        assertEq(sai.balanceOf(address(this)),    0 ether);
        assertEq(gem.balanceOf(address(this)), 1010 ether);
    }
    function testTaxCage() public {
        // after cage, un-distributed tax revenue remains as joy - sai
        // surplus in the tap. The remaining joy, plus all outstanding
        // sai, balances the sin debt in the cdpManager, plus any debt (woe) in
        // the tap.

        // The effect of this is that joy remaining in tap is
        // effectively distributed to all skr holders.
        bytes32 cdp = taxSetup();
        warp(1 days);
        mark(10 ether);

        assertEq(tap.joy(), 0 ether);
        top.cage();                // should drip up to date
        assertEq(tap.joy(), 5 ether);
        warp(1 days);  cdpManager.drip();  // should have no effect
        assertEq(tap.joy(), 5 ether);

        uint owe = cdpManager.tab(cdp);
        assertEq(owe, 105 ether);
        assertEq(cdpManager.din(), owe);
        assertEq(tap.woe(), 0);
        cdpManager.bite(cdp);
        assertEq(cdpManager.din(), 0);
        assertEq(tap.woe(), owe);
        assertEq(tap.joy(), 5 ether);
    }
}

contract WayTest is SaiTestBase {
    function waySetup() public returns (bytes32 cdp) {
        mark(10 ether);
        gem.deposit{value: 1000 ether}();

        mom.setCap(1000 ether);

        cdp = cdpManager.open();
        cdpManager.join(100 ether);
        cdpManager.lock(cdp, 100 ether);
        cdpManager.draw(cdp, 100 ether);
    }
    // what does way actually do?
    // it changes the value of sai relative to ref
    // way > 1 -> par increasing, more ref per sai
    // way < 1 -> par decreasing, less ref per sai

    // this changes the safety level of cdps,
    // affecting `draw`, `wipe`, `free` and `bite`

    // if way < 1, par is decreasing and the con (in ref)
    // of a cdp is decreasing, so cdp holders need
    // less ref to wipe (but the same sai)
    // This makes cdps *more* collateralised with time.
    function testTau() public {
        assertEq(uint(targetPriceFeed.era()), block.timestamp);
        assertEq(uint(targetPriceFeed.tau()), block.timestamp);
    }
    function testWayPar() public {
        mom.setWay(999999406327787478619865402);  // -5% / day

        assertEq(wad(targetPriceFeed.targetPrice()), 1.00 ether);
        warp(1 days);
        assertEq(wad(targetPriceFeed.targetPrice()), 0.95 ether);

        mom.setWay(1000000021979553151239153027);  // 200% / year
        warp(365 days);
        assertEq(wad(targetPriceFeed.targetPrice()), 1.90 ether);
    }
    function testWayDecreasingPrincipal() public {
        bytes32 cdp = waySetup();
        mark(0.98 ether);
        assertTrue(!cdpManager.safe(cdp));

        mom.setWay(999999406327787478619865402);  // -5% / day
        warp(1 days);
        assertTrue(cdpManager.safe(cdp));
    }
    // `cage` is slightly affected: the cage price is
    // now in *sai per gem*, where before ref per gem
    // was equivalent.
    // `bail` is unaffected, as all values are in sai.
    function testWayCage() public {
        waySetup();

        mom.setWay(1000000021979553151239153027);  // 200% / year
        warp(365 days);  // par now 2

        // we have 100 sai
        // gem is worth 10 ref
        // sai is worth 2 ref
        // we should get back 100 / (10 / 2) = 20 gem

        top.cage();

        assertEq(gem.balanceOf(address(this)), 1000 ether);
        assertEq(sai.balanceOf(address(this)),  100 ether);
        assertEq(sai.balanceOf(address(tap)),     0 ether);
        tap.cash(sai.balanceOf(address(this)));
        assertEq(gem.balanceOf(address(this)), 1020 ether);
        assertEq(sai.balanceOf(address(this)),    0 ether);
        assertEq(sai.balanceOf(address(tap)),     0 ether);
    }

    // `boom` and `bust` as par is now needed to determine
    // the skr / sai price.
    function testWayBust() public {
        bytes32 cdp = waySetup();
        mark(0.5 ether);
        cdpManager.bite(cdp);

        assertEq(tap.joy(),   0 ether);
        assertEq(tap.woe(), 100 ether);
        assertEq(tap.fog(), 100 ether);
        assertEq(sai.balanceOf(address(this)), 100 ether);

        tap.bust(50 ether);

        assertEq(tap.fog(),  50 ether);
        assertEq(tap.woe(),  75 ether);
        assertEq(sai.balanceOf(address(this)), 75 ether);

        mom.setWay(999999978020447331861593082);  // -50% / year
        warp(365 days);
        assertEq(wad(targetPriceFeed.targetPrice()), 0.5 ether);
        // sai now worth half as much, so we cover twice as much debt
        // for the same skr
        tap.bust(50 ether);

        assertEq(tap.fog(),   0 ether);
        assertEq(tap.woe(),  25 ether);
        assertEq(sai.balanceOf(address(this)), 25 ether);
    }
}

contract GapTest is SaiTestBase {
    // boom and bust have a spread parameter
    function setUp() public override {
        super.setUp();

        gem.deposit{value: 500 ether}();
        cdpManager.join(500 ether);

        sai.mint(500 ether);
        sin.mint(500 ether);

        mark(2 ether);  // 2 ref per eth => 2 sai per skr
    }
    function testGapSaiTapBid() public {
        mark(1 ether);
        mom.setTapGap(1.01 ether);  // 1% spread
        assertEq(tap.bid(1 ether), 0.99 ether);
        mark(2 ether);
        assertEq(tap.bid(1 ether), 1.98 ether);
    }
    function testGapSaiTapAsk() public {
        mark(1 ether);
        mom.setTapGap(1.01 ether);  // 1% spread
        assertEq(tap.ask(1 ether), 1.01 ether);
        mark(2 ether);
        assertEq(tap.ask(1 ether), 2.02 ether);
    }
    function testGapBoom() public {
        sai.push(address(tap), 198 ether);
        assertEq(tap.joy(), 198 ether);

        mom.setTapGap(1.01 ether);  // 1% spread

        uint sai_before = sai.balanceOf(address(this));
        uint skr_before = skr.balanceOf(address(this));
        tap.boom(50 ether);
        uint sai_after = sai.balanceOf(address(this));
        uint skr_after = skr.balanceOf(address(this));
        assertEq(sai_after - sai_before, 99 ether);
        assertEq(skr_before - skr_after, 50 ether);
    }
    function testGapBust() public {
        skr.push(address(tap), 100 ether);
        sin.push(address(tap), 200 ether);
        assertEq(tap.fog(), 100 ether);
        assertEq(tap.woe(), 200 ether);

        mom.setTapGap(1.01 ether);

        uint sai_before = sai.balanceOf(address(this));
        uint skr_before = skr.balanceOf(address(this));
        tap.bust(50 ether);
        uint sai_after = sai.balanceOf(address(this));
        uint skr_after = skr.balanceOf(address(this));
        assertEq(skr_after - skr_before,  50 ether);
        assertEq(sai_before - sai_after, 101 ether);
    }
    function testGapLimits() public {
        uint256 legal   = 1.04 ether;
        uint256 illegal = 1.06 ether;

        (bool result,) = address(mom).call(abi.encodeWithSignature("setTapGap(uint256)", legal));
        assertTrue(result);
        assertEq(tap.gap(), legal);

        (result,) = address(mom).call(abi.encodeWithSignature("setTapGap(uint256)", illegal));
        assertTrue(!result);
        assertEq(tap.gap(), legal);
    }

    // join and exit have a spread parameter
    function testGapJarBidAsk() public {
        assertEq(cdpManager.per(), ray(1 ether));
        assertEq(cdpManager.bid(1 ether), 1 ether);
        assertEq(cdpManager.ask(1 ether), 1 ether);

        mom.setTubGap(1.01 ether);
        assertEq(cdpManager.bid(1 ether), 0.99 ether);
        assertEq(cdpManager.ask(1 ether), 1.01 ether);

        assertEq(skr.balanceOf(address(this)), 500 ether);
        assertEq(skr.totalSupply(),   500 ether);
        skr.burn(250 ether);

        assertEq(cdpManager.per(), ray(2 ether));
        assertEq(cdpManager.bid(1 ether), 1.98 ether);
        assertEq(cdpManager.ask(1 ether), 2.02 ether);
    }
    function testGapJoin() public {
        gem.deposit{value: 100 ether}();

        mom.setTubGap(1.05 ether);
        uint skr_before = skr.balanceOf(address(this));
        uint gem_before = gem.balanceOf(address(this));
        cdpManager.join(100 ether);
        uint skr_after = skr.balanceOf(address(this));
        uint gem_after = gem.balanceOf(address(this));

        assertEq(skr_after - skr_before, 100 ether);
        assertEq(gem_before - gem_after, 105 ether);
    }
    function testGapExit() public {
        gem.deposit{value: 100 ether}();
        cdpManager.join(100 ether);

        mom.setTubGap(1.05 ether);
        uint skr_before = skr.balanceOf(address(this));
        uint gem_before = gem.balanceOf(address(this));
        cdpManager.exit(100 ether);
        uint skr_after = skr.balanceOf(address(this));
        uint gem_after = gem.balanceOf(address(this));

        assertEq(gem_after - gem_before,  95 ether);
        assertEq(skr_before - skr_after, 100 ether);
    }
}

contract GasTest is SaiTestBase {
    bytes32 cdp;
    function setUp() public override {
        super.setUp();

        mark(1 ether);
        gem.deposit{value: 1000 ether}();

        mom.setCap(1000 ether);
        mom.setAxe(ray(1 ether));
        mom.setMat(ray(1 ether));
        mom.setTax(ray(1 ether));
        mom.setFee(ray(1 ether));
        mom.setTubGap(1 ether);
        mom.setTapGap(1 ether);

        cdp = cdpManager.open();
        cdpManager.join(1000 ether);
        cdpManager.lock(cdp, 500 ether);
        cdpManager.draw(cdp, 100 ether);
    }
    function doLock(uint256 wad) public logs_gas {
        cdpManager.lock(cdp, wad);
    }
    function doFree(uint256 wad) public logs_gas {
        cdpManager.free(cdp, wad);
    }
    function doDraw(uint256 wad) public logs_gas {
        cdpManager.draw(cdp, wad);
    }
    function doWipe(uint256 wad) public logs_gas {
        cdpManager.wipe(cdp, wad);
    }
    function doDrip() public logs_gas {
        cdpManager.drip();
    }
    function doBoom(uint256 wad) public logs_gas {
        tap.boom(wad);
    }

    uint256 tic = 15 seconds;

    function testGasLock() public {
        warp(tic);
        doLock(100 ether);
        // assertTrue(false);
    }
    function testGasFree() public {
        warp(tic);
        doFree(100 ether);
        // assertTrue(false);
    }
    function testGasDraw() public {
        warp(tic);
        doDraw(100 ether);
        // assertTrue(false);
    }
    function testGasWipe() public {
        warp(tic);
        doWipe(100 ether);
        // assertTrue(false);
    }
    function testGasBoom() public {
        warp(tic);
        cdpManager.join(10 ether);
        sai.mint(100 ether);
        sai.push(address(tap), 100 ether);
        skr.approve(address(tap), type(uint256).max);
        doBoom(1 ether);
        // assertTrue(false);
    }
    function testGasBoomHeal() public {
        warp(tic);
        cdpManager.join(10 ether);
        sai.mint(100 ether);
        sin.mint(100 ether);
        sai.push(address(tap), 100 ether);
        sin.push(address(tap),  50 ether);
        skr.approve(address(tap), type(uint256).max);
        doBoom(1 ether);
        // assertTrue(false);
    }
    function testGasDripNoop() public {
        cdpManager.drip();
        doDrip();
    }
    function testGasDrip1s() public {
        warp(1 seconds);
        doDrip();
    }
    function testGasDrip1m() public {
        warp(1 minutes);
        doDrip();
    }
    function testGasDrip1h() public {
        warp(1 hours);
        doDrip();
    }
    function testGasDrip1d() public {
        warp(1 days);
        doDrip();
    }
}

contract FeeTest is SaiTestBase {
    function feeSetup() public returns (bytes32 cdp) {
        mark(10 ether);
        mark(gov, 1 ether / 2);
        gem.deposit{value: 1000 ether}();
        gov.mint(100 ether);

        mom.setCap(1000 ether);
        mom.setFee(1000000564701133626865910626);  // 5% / day

        // warp(1 days);  // make chi,rhi != 1

        cdp = cdpManager.open();
        cdpManager.join(100 ether);
        cdpManager.lock(cdp, 100 ether);
        cdpManager.draw(cdp, 100 ether);
    }
    function testFeeSet() public {
        assertEq(cdpManager.fee(), ray(1 ether));
        mom.setFee(ray(1.000000001 ether));
        assertEq(cdpManager.fee(), ray(1.000000001 ether));
    }
    function testFeeSetup() public {
        feeSetup();
        assertEq(cdpManager.chi(), ray(1 ether));
        assertEq(cdpManager.rhi(), ray(1 ether));
    }
    function testFeeDrip() public {
        feeSetup();
        warp(1 days);
        assertEq(cdpManager.chi() / 10 ** 9, 1.00 ether);
        assertEq(cdpManager.rhi() / 10 ** 9, 1.05 ether);
    }
    // Unpaid fees do not accumulate as sin
    function testFeeIce() public {
        bytes32 cdp = feeSetup();
        assertEq(cdpManager.din(),    100 ether);
        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.rap(cdp),   0 ether);
        warp(1 days);
        assertEq(cdpManager.din(),    100 ether);
        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.rap(cdp),   5 ether);
    }
    function testFeeDraw() public {
        bytes32 cdp = feeSetup();
        warp(1 days);
        assertEq(cdpManager.rap(cdp),   5 ether);
        cdpManager.draw(cdp, 100 ether);
        assertEq(cdpManager.rap(cdp),   5 ether);
        warp(1 days);
        assertEq(cdpManager.rap(cdp),  15.25 ether);
    }
    function testFeeWipe() public {
        bytes32 cdp = feeSetup();
        warp(1 days);
        assertEq(cdpManager.rap(cdp),   5 ether);
        cdpManager.wipe(cdp, 50 ether);
        assertEq(cdpManager.rap(cdp),  2.5 ether);
        warp(1 days);
        assertEq(cdpManager.rap(cdp),  5.125 ether);
    }
    function testFeeCalcFromRap() public {
        bytes32 cdp = feeSetup();

        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.rap(cdp),   0 ether);
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.rap(cdp),   5 ether);
    }
    function testFeeWipePays() public {
        bytes32 cdp = feeSetup();
        warp(1 days);

        assertEq(cdpManager.rap(cdp),          5 ether);
        assertEq(gov.balanceOf(address(this)), 100 ether);
        cdpManager.wipe(cdp, 50 ether);
        assertEq(cdpManager.tab(cdp),         50 ether);
        assertEq(gov.balanceOf(address(this)),  95 ether);
    }
    function testFeeWipeMoves() public {
        bytes32 cdp = feeSetup();
        warp(1 days);

        assertEq(gov.balanceOf(address(this)), 100 ether);
        assertEq(gov.balanceOf(address(pit)),    0 ether);
        cdpManager.wipe(cdp, 50 ether);
        assertEq(gov.balanceOf(address(this)),  95 ether);
        assertEq(gov.balanceOf(address(pit)),    5 ether);
    }
    function testFeeWipeAll() public {
        bytes32 cdp = feeSetup();
        warp(1 days);

        uint wad = cdpManager.tab(cdp);
        assertEq(wad, 100 ether);
        uint owe = cdpManager.rap(cdp);
        assertEq(owe, 5 ether);

        ( , , uint256 art, uint256 ire) = cdpManager.cdps(cdp);
        assertEq(art, 100 ether);
        assertEq(ire, 100 ether);
        assertEq(rdiv(wad, cdpManager.chi()), art);
        assertEq(rdiv(add(wad, owe), cdpManager.rhi()), ire);

        assertEq(cdpManager.rap(cdp),   5 ether);
        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(gov.balanceOf(address(this)), 100 ether);
        cdpManager.wipe(cdp, 100 ether);
        assertEq(cdpManager.rap(cdp), 0 ether);
        assertEq(cdpManager.tab(cdp), 0 ether);
        assertEq(gov.balanceOf(address(this)), 90 ether);
    }
    function testFeeWipeNoFeed() public {
        bytes32 cdp = feeSetup();
        pep.void();
        warp(1 days);

        // fees continue to accumulate
        assertEq(cdpManager.rap(cdp),   5 ether);

        // gov is no longer taken
        assertEq(gov.balanceOf(address(this)), 100 ether);
        cdpManager.wipe(cdp, 50 ether);
        assertEq(gov.balanceOf(address(this)), 100 ether);

        // fees are still wiped proportionally
        assertEq(cdpManager.rap(cdp),  2.5 ether);
        warp(1 days);
        assertEq(cdpManager.rap(cdp),  5.125 ether);
    }
    function testFeeWipeShut() public {
        bytes32 cdp = feeSetup();
        warp(1 days);
        cdpManager.shut(cdp);
    }
    function testFeeWipeShutEmpty() public {
        feeSetup();
        bytes32 cdp = cdpManager.open();
        cdpManager.join(100 ether);
        cdpManager.lock(cdp, 100 ether);
        warp(1 days);
        cdpManager.shut(cdp);
    }
}

contract PitTest is SaiTestBase {
    function testPitBurns() public {
        gov.mint(1 ether);
        assertEq(gov.balanceOf(address(pit)), 0 ether);
        gov.push(address(pit), 1 ether);

        // mock gov authority
        DSGuard guard = new DSGuard();
        guard.permit(address(pit), address(gov), bytes4(keccak256('burn(uint256)')));
        gov.setAuthority(guard);

        assertEq(gov.balanceOf(address(pit)), 1 ether);
        pit.burn(gov);
        assertEq(gov.balanceOf(address(pit)), 0 ether);
    }
}

contract FeeTaxTest is SaiTestBase {
    function feeSetup() public returns (bytes32 cdp) {
        mark(10 ether);
        mark(gov, 1 ether / 2);
        gem.deposit{value: 1000 ether}();
        gov.mint(100 ether);

        mom.setCap(1000 ether);
        mom.setFee(1000000564701133626865910626);  // 5% / day
        mom.setTax(1000000564701133626865910626);  // 5% / day

        // warp(1 days);  // make chi,rhi != 1

        cdp = cdpManager.open();
        cdpManager.join(100 ether);
        cdpManager.lock(cdp, 100 ether);
        cdpManager.draw(cdp, 100 ether);
    }
    function testFeeTaxDrip() public {
        feeSetup();
        warp(1 days);
        assertEq(cdpManager.chi() / 10 ** 9, 1.0500 ether);
        assertEq(cdpManager.rhi() / 10 ** 9, 1.1025 ether);
    }
    // Unpaid fees do not accumulate as sin
    function testFeeTaxIce() public {
        bytes32 cdp = feeSetup();

        assertEq(cdpManager.tab(cdp), 100 ether);
        assertEq(cdpManager.rap(cdp),   0 ether);

        assertEq(cdpManager.din(),    100 ether);
        assertEq(tap.joy(),      0 ether);

        warp(1 days);

        assertEq(cdpManager.tab(cdp), 105 ether);
        assertEq(cdpManager.rap(cdp),   5.25 ether);

        assertEq(cdpManager.din(),    105 ether);
        assertEq(tap.joy(),      5 ether);
    }
    function testFeeTaxDraw() public {
        bytes32 cdp = feeSetup();
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 105 ether);
        cdpManager.draw(cdp, 100 ether);
        assertEq(cdpManager.tab(cdp), 205 ether);
    }
    function testFeeTaxCalcFromRap() public {
        bytes32 cdp = feeSetup();

        assertEq(cdpManager.tab(cdp), 100.00 ether);
        assertEq(cdpManager.rap(cdp),   0.00 ether);
        warp(1 days);
        assertEq(cdpManager.tab(cdp), 105.00 ether);
        assertEq(cdpManager.rap(cdp),   5.25 ether);
    }
    function testFeeTaxWipeAll() public {
        bytes32 cdp = feeSetup();
        warp(1 days);

        uint wad = cdpManager.tab(cdp);
        assertEq(wad, 105 ether);
        uint owe = cdpManager.rap(cdp);
        assertEq(owe, 5.25 ether);

        ( , , uint256 art, uint256 ire) = cdpManager.cdps(cdp);
        assertEq(art, 100 ether);
        assertEq(ire, 100 ether);
        assertEq(rdiv(wad, cdpManager.chi()), art);
        assertEq(rdiv(add(wad, owe), cdpManager.rhi()), ire);

        sai.mint(5 ether);  // need to magic up some extra sai to pay tax

        assertEq(cdpManager.rap(cdp), 5.25 ether);
        assertEq(gov.balanceOf(address(this)), 100 ether);
        cdpManager.wipe(cdp, 105 ether);
        assertEq(cdpManager.rap(cdp), 0 ether);
        assertEq(gov.balanceOf(address(this)), 89.5 ether);
    }
}

contract AxeTest is SaiTestBase {
    function axeSetup() public returns (bytes32) {
        mom.setCap(1000 ether);
        mark(1 ether);
        mom.setMat(ray(2 ether));       // require 200% collat
        cdpManager.join(20 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 20 ether);
        cdpManager.draw(cdp, 10 ether);       // 200% collateralisation

        return cdp;
    }
    function testAxeBite1() public {
        bytes32 cdp = axeSetup();

        mom.setAxe(ray(1.5 ether));
        mom.setMat(ray(2.1 ether));

        assertEq(cdpManager.ink(cdp), 20 ether);
        cdpManager.bite(cdp);
        assertEq(cdpManager.ink(cdp), 5 ether);
    }
    function testAxeBite2() public {
        bytes32 cdp = axeSetup();

        mom.setAxe(ray(1.5 ether));
        mark(0.8 ether);    // collateral value 20 -> 16

        assertEq(cdpManager.ink(cdp), 20 ether);
        cdpManager.bite(cdp);
        assertEq(cdpManager.ink(cdp), 1.25 ether);  // (1 / 0.8)
    }
    function testAxeBiteParity() public {
        bytes32 cdp = axeSetup();

        mom.setAxe(ray(1.5 ether));
        mark(0.5 ether);    // collateral value 20 -> 10

        assertEq(cdpManager.ink(cdp), 20 ether);
        cdpManager.bite(cdp);
        assertEq(cdpManager.ink(cdp), 0 ether);
    }
    function testAxeBiteUnder() public {
        bytes32 cdp = axeSetup();

        mom.setAxe(ray(1.5 ether));
        mark(0.4 ether);    // collateral value 20 -> 8

        assertEq(cdpManager.ink(cdp), 20 ether);
        cdpManager.bite(cdp);
        assertEq(cdpManager.ink(cdp), 0 ether);
    }
    function testZeroAxeCage() public {
        bytes32 cdp = axeSetup();

        mom.setAxe(ray(1 ether));

        assertEq(cdpManager.ink(cdp), 20 ether);
        top.cage();
        cdpManager.bite(cdp);
        tap.vent();
        top.flow();
        assertEq(cdpManager.ink(cdp), 10 ether);
    }
    function testAxeCage() public {
        bytes32 cdp = axeSetup();

        mom.setAxe(ray(1.5 ether));

        assertEq(cdpManager.ink(cdp), 20 ether);
        top.cage();
        cdpManager.bite(cdp);
        tap.vent();
        top.flow();
        assertEq(cdpManager.ink(cdp), 10 ether);
    }
}

contract DustTest is SaiTestBase {
    function testFailLockUnderDust() public {
        cdpManager.join(1 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 0.0049 ether);
    }
    function testFailFreeUnderDust() public {
        cdpManager.join(1 ether);
        bytes32 cdp = cdpManager.open();
        cdpManager.lock(cdp, 1 ether);
        cdpManager.free(cdp, 0.995 ether);
    }
}

contract SymbologyTest is SaiTestBase {
    function testSymbology() public {
        assertEq(sai.symbol(), 'DAI');
        assertEq(sin.symbol(), 'SIN');
        assertEq(skr.symbol(), 'PETH');

        assertEq(sai.name(), 'Dai Stablecoin v1.0');
        assertEq(sin.name(), 'SIN');
        assertEq(skr.name(), 'Pooled Ether');
    }
}

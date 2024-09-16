/// CDPManager.t.sol -- Unit tests for CDPManager.sol

pragma solidity >=0.8.0;

import './CDPManager.sol';
import './tap.sol';
import './ds-guard/guard.sol';
import "./ds-test/test.sol";

contract CDPManagerTest is DSTest, DSThing {
    address tap;
    CDPManager  cdpManager;
    TargetPriceFeed  targetPriceFeed;

    DSGuard dad;

    DSValue pip;
    DSValue pep;

    DSToken sai;
    DSToken sin;
    DSToken skr;
    DSToken gem;
    DSToken gov;

    function setUp() public {
        sai = new DSToken("SAI");
        sin = new DSToken("SIN");
        skr = new DSToken("SKR");
        gem = new DSToken("GEM");
        gov = new DSToken("GOV");
        pip = new DSValue();
        pep = new DSValue();
        dad = new DSGuard();
        targetPriceFeed = new TargetPriceFeed(RAY);
        cdpManager = new CDPManager(sai, sin, skr, IERC20(address(gem)), gov, pip, pep, targetPriceFeed, address(0x123));
        tap = address(0x456);
        cdpManager.turn(tap);

        //Set whitelist authority
        skr.setAuthority(dad);

        //Permit cdpManager to 'mint' and 'burn' SKR
        dad.permit(address(cdpManager), address(skr), bytes4(keccak256('mint(address,uint256)')));
        dad.permit(address(cdpManager), address(skr), bytes4(keccak256('burn(address,uint256)')));

        //Allow cdpManager to mint, burn, and transfer gem/skr without approval
        gem.approve(address(cdpManager));
        skr.approve(address(cdpManager));
        sai.approve(address(cdpManager));

        gem.mint(6 ether);

        //Verify initial token balances
        assertEq(gem.balanceOf(address(this)), 6 ether);
        assertEq(gem.balanceOf(address(cdpManager)), 0 ether);
        assertEq(skr.totalSupply(), 0 ether);

        assert(!cdpManager.off());
    }

    function testFailTurnAgain() public {
        cdpManager.turn(address(0x789));
    }

    function testPie() public {
        assertEq(cdpManager.pie(), gem.balanceOf(address(cdpManager)));
        assertEq(cdpManager.pie(), 0 ether);
        gem.mint(75 ether);
        cdpManager.join(72 ether);
        assertEq(cdpManager.pie(), gem.balanceOf(address(cdpManager)));
        assertEq(cdpManager.pie(), 72 ether);
    }

    function testPer() public {
        cdpManager.join(5 ether);
        assertEq(skr.totalSupply(), 5 ether);
        assertEq(cdpManager.per(), rdiv(5 ether, 5 ether));
    }

    function testTag() public {
        cdpManager.pip().poke(bytes32(uint(1 ether)));
        assertEq(cdpManager.pip().read(), bytes32(uint(1 ether)));
        assertEq(wmul(cdpManager.per(), uint(cdpManager.pip().read())), cdpManager.tag());
        cdpManager.pip().poke(bytes32(uint(5 ether)));
        assertEq(cdpManager.pip().read(), bytes32(uint(5 ether)));
        assertEq(wmul(cdpManager.per(), uint(cdpManager.pip().read())), cdpManager.tag());
    }

    function testGap() public {
        assertEq(cdpManager.joinExitSpread(), WAD);
        cdpManager.mold('gap', 2 ether);
        assertEq(cdpManager.joinExitSpread(), 2 ether);
        cdpManager.mold('gap', wmul(WAD, 10 ether));
        assertEq(cdpManager.joinExitSpread(), wmul(WAD, 10 ether));
    }

    function testAsk() public {
        assertEq(cdpManager.per(), RAY);
        assertEq(cdpManager.ask(3 ether), rmul(3 ether, wmul(RAY, cdpManager.joinExitSpread())));
        assertEq(cdpManager.ask(wmul(WAD, 33)), rmul(wmul(WAD, 33), wmul(RAY, cdpManager.joinExitSpread())));
    }

    function testBid() public {
        assertEq(cdpManager.per(), RAY);
        assertEq(cdpManager.bid(4 ether), rmul(4 ether, wmul(cdpManager.per(), sub(2 * WAD, cdpManager.joinExitSpread()))));
        assertEq(cdpManager.bid(wmul(5 ether,3333333)), rmul(wmul(5 ether,3333333), wmul(cdpManager.per(), sub(2 * WAD, cdpManager.joinExitSpread()))));
    }

    function testJoin() public {
        cdpManager.join(3 ether);
        assertEq(gem.balanceOf(address(this)), 3 ether);
        assertEq(gem.balanceOf(address(cdpManager)), 3 ether);
        assertEq(skr.totalSupply(), 3 ether);
        cdpManager.join(1 ether);
        assertEq(gem.balanceOf(address(this)), 2 ether);
        assertEq(gem.balanceOf(address(cdpManager)), 4 ether);
        assertEq(skr.totalSupply(), 4 ether);
    }

    function testExit() public {
        gem.mint(10 ether);
        assertEq(gem.balanceOf(address(this)), 16 ether);

        cdpManager.join(12 ether);
        assertEq(gem.balanceOf(address(cdpManager)), 12 ether);
        assertEq(gem.balanceOf(address(this)), 4 ether);
        assertEq(skr.totalSupply(), 12 ether);

        cdpManager.exit(3 ether);
        assertEq(gem.balanceOf(address(cdpManager)), 9 ether);
        assertEq(gem.balanceOf(address(this)), 7 ether);
        assertEq(skr.totalSupply(), 9 ether);

        cdpManager.exit(7 ether);
        assertEq(gem.balanceOf(address(cdpManager)), 2 ether);
        assertEq(gem.balanceOf(address(this)), 14 ether);
        assertEq(skr.totalSupply(), 2 ether);
    }

    function testCage() public {
        cdpManager.join(5 ether);
        assertEq(gem.balanceOf(address(cdpManager)), 5 ether);
        assertEq(gem.balanceOf(address(this)), 1 ether);
        assertEq(skr.totalSupply(), 5 ether);
        assert(!cdpManager.off());

        cdpManager.cage(cdpManager.per(), 5 ether);
        assertEq(gem.balanceOf(address(cdpManager)), 0 ether);
        assertEq(gem.balanceOf(address(tap)), 5 ether);
        assertEq(skr.totalSupply(), 5 ether);
        assert(cdpManager.off());
    }

    function testFlow() public {
        cdpManager.join(1 ether);
        cdpManager.cage(cdpManager.per(), 1 ether);
        assert(cdpManager.off());
        assert(!cdpManager.out());
        cdpManager.flow();
        assert(cdpManager.out());
    }
}

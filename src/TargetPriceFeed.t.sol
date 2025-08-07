pragma solidity >=0.8.0;

import "./ds-test/test.sol";
import "./ds-math/math.sol";
import './TargetPriceFeed.sol';

contract TestWarp is DSNote {
    uint  _era;

    constructor() {
        _era = block.timestamp;
    }

    function era() public view virtual returns (uint) {
        return _era == 0 ? block.timestamp : _era;
    }

    function warp(uint age) public note {
        _era = age == 0 ? 0 : _era + age;
    }
}

contract DevTargetPriceFeed is TargetPriceFeed, TestWarp {
    constructor(uint par_) TargetPriceFeed(par_) TestWarp() {}

    function era() public view override(TargetPriceFeed, TestWarp) returns (uint256) {
      return super.era();
    }
}

contract TargetPriceFeedTest is DSTest, DSMath {
    DevTargetPriceFeed targetPriceFeed;

    function wad(uint256 ray_) internal pure returns (uint256) {
        return wdiv(ray_, RAY);
    }

    function setUp() public {
        targetPriceFeed = new DevTargetPriceFeed(RAY);
    }
    function testDefaultTargetPrice() public {
        assertEq(targetPriceFeed.targetPrice(), RAY);
    }
    function testDefaultRateOfChange() public {
        assertEq(targetPriceFeed.rateOfChangePerSecond(), RAY);
    }
    function testVoxCoax() public {
        targetPriceFeed.mold('way', 999999406327787478619865402);  // -5% / day
        assertEq(targetPriceFeed.rateOfChangePerSecond(), 999999406327787478619865402);
    }
    function testVoxProd() public {
        targetPriceFeed.mold('way', 999999406327787478619865402);  // -5% / day
        targetPriceFeed.prod();
    }
    function testVoxProdAfterWarp1day() public {
        targetPriceFeed.mold('way', 999999406327787478619865402);  // -5% / day
        targetPriceFeed.warp(1 days);
        targetPriceFeed.prod();
    }
    function testTargetPriceAfterWarp1day() public {
        targetPriceFeed.mold('way', 999999406327787478619865402);  // -5% / day
        targetPriceFeed.warp(1 days);
        assertEq(wad(targetPriceFeed.targetPrice()), 0.95 ether);
    }
    function testVoxProdAfterWarp2day() public {
        targetPriceFeed.mold('way', 999991977495368425989823173);  // -50% / day
        targetPriceFeed.warp(2 days);
        assertEq(wad(targetPriceFeed.targetPrice()), 0.25 ether);
    }
}

contract VoxHowTest is DSTest, DSMath {
    DevTargetPriceFeed targetPriceFeed;

    function ray(uint256 wad_) internal pure returns (uint256) {
        return wad_ * 10 ** 9;
    }
    function setUp() public {
        targetPriceFeed = new DevTargetPriceFeed(ray(0.75 ether));
        targetPriceFeed.tune(ray(0.002 ether));
    }
    function test_price_too_low() public {
        targetPriceFeed.tell(ray(0.70 ether));
        targetPriceFeed.warp(1 seconds);
        assertEq(targetPriceFeed.rateOfChangePerSecond(), ray(1.002 ether));
        targetPriceFeed.warp(2 seconds);
        assertEq(targetPriceFeed.rateOfChangePerSecond(), ray(1.006 ether));
    }

    function test_price_too_high() public {
        targetPriceFeed.tell(ray(0.80 ether));
        targetPriceFeed.warp(1 seconds);
        assertEq(targetPriceFeed.rateOfChangePerSecond(), 998003992015968063872255489);
        targetPriceFeed.warp(2 seconds);
        assertEq(targetPriceFeed.rateOfChangePerSecond(), 994035785288270377733598410);
    }
}

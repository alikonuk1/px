// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/Px.sol";
import "./mock/MockUni.sol";
import "../src/Treasury.sol";
import "./mock/MockERC20.sol";
import "./mock/MockProxy.sol";

contract PxTest is Test {
    Px px;
    MockERC20 usdc;
    MockERC20 weth;
    MockUni uni;
    MockProxy proxy;
    Treasury treasury;

    address creator = address(1);
    address user1 = address(2);
    address user2 = address(3);
    address user3 = address(4);
    address user4 = address(5);
    address user5 = address(6);
    address user6 = address(7);
    address api3ServerV1 = address(9);
    address protocol = address(32);

    function setUp() public {
        vm.startPrank(creator);

        // deploy mock tokens
        usdc = new MockERC20( "Usdc", "USDC", 6);
        weth = new MockERC20( "Weth", "WETH", 18);

        // deploy and set mock proxy
        proxy = new MockProxy(api3ServerV1);
        proxy.mock(1800, 1);

        // deploy mock uni
        uni = new MockUni(address(proxy), address(usdc), address(weth));

        // deploy treasury
        treasury = new Treasury();

        // deploy px
        px = new Px(address(proxy), address(usdc), address(weth), address(treasury));

        // set px address and router address on treasury
        treasury.setPx(address(px));
        treasury.setRouter(address(uni));

        vm.stopPrank();

        // top up accounts with mock usdc
        usdc.mint(creator);
        usdc.mint(user1);
        usdc.mint(user2);
        usdc.mint(user3);
        usdc.mint(user4);
        usdc.mint(user5);
        usdc.mint(user6);
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));
        usdc.mint(address(uni));

        // top up accounts with mock weth
        weth.mint(creator);
        weth.mint(user1);
        weth.mint(user2);
        weth.mint(user3);
        weth.mint(user4);
        weth.mint(user5);
        weth.mint(user6);
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
        weth.mint(address(uni));
    }

    /////////////////////////////////////////////
    //               Constructor
    /////////////////////////////////////////////

    function testSuccess_Constructor() public {
        assertEq(px.proxy(), address(proxy));
        assertEq(px.owner(), address(creator));
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                    Admin Stuff
    //////////////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////
    //                setProxy
    /////////////////////////////////////////////

    function testSuccess_setProxy(address newProxy) public {
        vm.startPrank(creator);
        px.setProxy(newProxy);
        vm.stopPrank();
        assertEq(px.proxy(), newProxy);
    }

    function testRevert_setProxy(address newProxy) public {
        vm.startPrank(user1);
        vm.expectRevert("!owner");
        px.setProxy(newProxy);
        vm.stopPrank();
        assertEq(px.proxy(), address(proxy));
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                      Oracle
    //////////////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////
    //                getPrice
    /////////////////////////////////////////////

    function testSuccess_getPrice(int224 price, uint32 timestamp) public {
        vm.assume(price > 0);
        vm.startPrank(api3ServerV1);
        proxy.mock(price, timestamp);
        vm.stopPrank();
        /* assertEq(px.getPrice(), price); */
    }

    function testRevert_getPrice_NonPositiveValue(int224 price, uint32 timestamp) public {
        vm.assume(price < 0);
        vm.startPrank(api3ServerV1);
        proxy.mock(price, timestamp);
        vm.stopPrank();
        /*         vm.expectRevert("Value not positive");
        px.getPrice(); */
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                      Liquidity
    //////////////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////
    //             provideLiquidity
    /////////////////////////////////////////////

    function testSuccess_provideLiquidity(uint256 amount) public {
        vm.assume(amount < 100 ether && amount > 0.1 ether);

        vm.startPrank(user1);
        usdc.approve(address(px), amount);
        px.provideLiquidity(amount, false);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user1), 100 ether - amount);
        assertEq(usdc.balanceOf(address(treasury)), amount);

        vm.startPrank(user2);
        weth.approve(address(px), amount);
        px.provideLiquidity(amount, true);
        vm.stopPrank();

        assertEq(weth.balanceOf(user2), 100 ether - amount);
        assertEq(weth.balanceOf(address(treasury)), amount);
    }

    /////////////////////////////////////////////
    //             withdrawLiquidity
    /////////////////////////////////////////////

    function testSuccess_withdrawLiquidity(uint256 amount) public {
        vm.assume(amount < 100 ether && amount > 0.1 ether);

        assertEq(usdc.balanceOf(user1), 100 ether);
        assertEq(usdc.balanceOf(address(treasury)), 0);

        vm.startPrank(user1);
        usdc.approve(address(px), amount);
        px.provideLiquidity(amount, false);

        assertEq(usdc.balanceOf(user1), 100 ether - amount);
        assertEq(usdc.balanceOf(address(treasury)), amount);

        px.withdrawLiquidity(amount, false);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user1), 100 ether);
        assertEq(usdc.balanceOf(address(treasury)), 0);

        assertEq(weth.balanceOf(user3), 100 ether);
        assertEq(weth.balanceOf(address(treasury)), 0);

        vm.startPrank(user3);
        weth.approve(address(px), amount);
        px.provideLiquidity(amount, true);

        assertEq(weth.balanceOf(user3), 100 ether - amount);
        assertEq(weth.balanceOf(address(treasury)), amount);

        px.withdrawLiquidity(amount, true);
        vm.stopPrank();

        assertEq(weth.balanceOf(user3), 100 ether);
        assertEq(weth.balanceOf(address(treasury)), 0);
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                      Collateral
    //////////////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////
    //                deposit
    /////////////////////////////////////////////

    function testSuccess_deposit(uint256 amount) public {
        vm.assume(amount < 100 ether && amount > 0.001 ether);

        assertEq(usdc.balanceOf(user1), 100 ether);
        assertEq(usdc.balanceOf(address(px)), 0);
        assertEq(weth.balanceOf(user3), 100 ether);
        assertEq(weth.balanceOf(address(px)), 0);

        vm.startPrank(user1);
        usdc.approve(address(px), amount);
        px.deposit(amount, false);
        vm.stopPrank();

        vm.startPrank(user3);
        weth.approve(address(px), amount);
        px.deposit(amount, true);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user1), 100 ether - amount);
        assertEq(usdc.balanceOf(address(px)), amount);
        assertEq(weth.balanceOf(user3), 100 ether - amount);
        assertEq(weth.balanceOf(address(px)), amount);
    }

    /////////////////////////////////////////////
    //                withdraw
    /////////////////////////////////////////////

    function testSuccess_withdraw(uint256 amount) public {
        vm.assume(amount < 100 ether && amount > 0.001 ether);

        assertEq(usdc.balanceOf(user1), 100 ether);
        assertEq(usdc.balanceOf(address(px)), 0);
        assertEq(weth.balanceOf(user3), 100 ether);
        assertEq(weth.balanceOf(address(px)), 0);

        vm.startPrank(user1);
        usdc.approve(address(px), amount);
        px.deposit(amount, false);
        vm.stopPrank();

        vm.startPrank(user3);
        weth.approve(address(px), amount);
        px.deposit(amount, true);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user1), 100 ether - amount);
        assertEq(usdc.balanceOf(address(px)), amount);
        assertEq(weth.balanceOf(user3), 100 ether - amount);
        assertEq(weth.balanceOf(address(px)), amount);

        vm.startPrank(user1);
        px.withdraw(amount, false);
        vm.stopPrank();

        vm.startPrank(user3);
        px.withdraw(amount, true);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user1), 100 ether);
        assertEq(usdc.balanceOf(address(px)), 0);
        assertEq(weth.balanceOf(user3), 100 ether);
        assertEq(weth.balanceOf(address(px)), 0);
    }

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                    Trading Logic
    //////////////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////////////
    //               openPosition
    /////////////////////////////////////////////

    function testRevert_openPosition_NoBalance(uint256 amount, bool isLong, bool isWeth, uint8 leverage) public {
        vm.assume(amount < 100 ether && amount > 0.001 ether);
        vm.assume(leverage <= 10);

        vm.startPrank(user1);
        vm.expectRevert("Insufficient user balance");
        px.openPosition(amount, isLong, isWeth, leverage);
        vm.stopPrank();
    }

    function testRevert_openPosition_OverLeverage(uint256 amount, bool isLong, bool isWeth, uint8 leverage) public {
        vm.assume(amount < 100 ether && amount > 0.001 ether);
        vm.assume(leverage > 10);

        vm.startPrank(user1);
        vm.expectRevert("Insufficient user balance");
        px.openPosition(amount, isLong, isWeth, 1);
        vm.stopPrank();
    }

    function testSuccess_openPosition(uint8 leverage) public {
        vm.assume(leverage <= 10);
        uint256 amount = 0.01 ether; 

        // top up treasury balance with liqudity providers
        vm.startPrank(user5);
        usdc.approve(address(px), 100 ether);
        px.provideLiquidity(100 ether, false);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user5), 100 ether - 100 ether);
        assertEq(usdc.balanceOf(address(treasury)), 100 ether);

        vm.startPrank(user5);
        weth.approve(address(px), 100 ether);
        px.provideLiquidity(100 ether, true);
        vm.stopPrank();

        assertEq(weth.balanceOf(user5), 100 ether - 100 ether);
        assertEq(weth.balanceOf(address(treasury)), 100 ether);

        vm.startPrank(user6);
        usdc.approve(address(px), 100 ether);
        px.provideLiquidity(100 ether, false);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user6), 100 ether - 100 ether);
        assertEq(usdc.balanceOf(address(treasury)), 200 ether);

        vm.startPrank(user6);
        weth.approve(address(px), 100 ether);
        px.provideLiquidity(100 ether, true);
        vm.stopPrank();

        assertEq(weth.balanceOf(user6), 100 ether - 100 ether);
        assertEq(weth.balanceOf(address(treasury)), 200 ether);

        assertEq(usdc.balanceOf(user1), 100 ether);
        assertEq(usdc.balanceOf(address(px)), 0);
        assertEq(weth.balanceOf(user3), 100 ether);
        assertEq(weth.balanceOf(address(px)), 0);

        vm.startPrank(user1);
        usdc.approve(address(px), amount);
        px.deposit(amount, false);
        vm.stopPrank();

        vm.startPrank(user3);
        weth.approve(address(px), amount);
        px.deposit(amount, true);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user1), 100 ether - amount);
        assertEq(usdc.balanceOf(address(px)), amount);
        assertEq(weth.balanceOf(user3), 100 ether - amount);
        assertEq(weth.balanceOf(address(px)), amount);

        vm.startPrank(user1);
        px.openPosition(amount, true, false, leverage);
        vm.stopPrank();

        vm.startPrank(user3);
        px.openPosition(amount, false, true, leverage);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user1), 100 ether - amount);
        assertEq(usdc.balanceOf(address(px)), 0);
        assertEq(weth.balanceOf(user3), 100 ether - amount);
        assertEq(weth.balanceOf(address(px)), 0);
    }

    /////////////////////////////////////////////
    //              closePosition
    /////////////////////////////////////////////

    function testRevert_closePosition_NoPosition() public {
        vm.startPrank(user1);
        vm.expectRevert();
        px.closePosition();
        vm.stopPrank();
    }

    /////////////////////////////////////////////
    //              End to End
    /////////////////////////////////////////////

    function testSuccess_EndToEnd() public {
        // top up treasury balance with liqudity providers
        vm.startPrank(user5);
        usdc.approve(address(px), 100 ether);
        px.provideLiquidity(100 ether, false);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user5), 100 ether - 100 ether);
        assertEq(usdc.balanceOf(address(treasury)), 100 ether);

        vm.startPrank(user5);
        weth.approve(address(px), 100 ether);
        px.provideLiquidity(100 ether, true);
        vm.stopPrank();

        assertEq(weth.balanceOf(user5), 100 ether - 100 ether);
        assertEq(weth.balanceOf(address(treasury)), 100 ether);

        vm.startPrank(user6);
        usdc.approve(address(px), 100 ether);
        px.provideLiquidity(100 ether, false);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user6), 100 ether - 100 ether);
        assertEq(usdc.balanceOf(address(treasury)), 200 ether);

        vm.startPrank(user6);
        weth.approve(address(px), 100 ether);
        px.provideLiquidity(100 ether, true);
        vm.stopPrank();

        assertEq(weth.balanceOf(user6), 100 ether - 100 ether);
        assertEq(weth.balanceOf(address(treasury)), 200 ether);

        // Checks before user openPosition
        assertEq(usdc.balanceOf(user1), 100 ether);
        assertEq(usdc.balanceOf(address(px)), 0);

        // User deposits 10 usdc, opens long position with 10x leverage and usdc as collateral
        vm.startPrank(user1);
        usdc.approve(address(px), 10 ether);
        px.deposit(10 ether, false);

        assertEq(usdc.balanceOf(user1), 100 ether - 10 ether);
        assertEq(usdc.balanceOf(address(px)), 10 ether);

        px.openPosition(10 ether, true, false, 10);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user1), 100 ether - 10 ether);
        assertEq(usdc.balanceOf(address(px)), 0);

        // Change mock api price
        vm.startPrank(creator);
        proxy.mock(2000, 100000000);
        vm.stopPrank();

        (bool isSolvent) = px.isSolvent(user1);

        assertEq(isSolvent, true);

        vm.startPrank(user1);
        px.closePosition();
        vm.stopPrank();
    }

}

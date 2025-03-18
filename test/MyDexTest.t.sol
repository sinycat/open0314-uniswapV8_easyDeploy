// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/MyDex.sol";
import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Router.sol";
import "../src/WETH9.sol";
import "../src/MyERC20Token.sol";

contract MyDexTest is Test {
    // 合约实例
    MyDex public dex;
    UniswapV2Factory public factory;
    UniswapV2Router public router;
    WETH9 public weth;
    MyERC20Token public rnt; // 模拟RNT代币
    
    // 测试账户
    address public user = address(1);
    uint256 public constant INITIAL_AMOUNT = 1000000 * 10**18;
    
    function setUp() public {
        // 部署WETH
        weth = new WETH9();
        
        // 部署RNT代币
        rnt = new MyERC20Token("RNT Token", "RNT");
        
        // 给测试用户铸造代币
        rnt.mint(user, INITIAL_AMOUNT);
        
        // 部署Factory
        factory = new UniswapV2Factory(address(0));
        
        // 部署Router
        router = new UniswapV2Router(address(factory), address(weth));
        
        // 部署MyDex
        dex = new MyDex(address(factory), address(router), address(weth));
        
        // 给用户一些ETH
        vm.deal(user, 100 ether);
        
        // 创建ETH/RNT交易对并添加流动性
        vm.startPrank(user);
        
        // 授权Router使用RNT代币
        rnt.approve(address(router), INITIAL_AMOUNT);
        
        // 添加ETH/RNT流动性
        router.addLiquidityETH{value: 10 ether}(
            address(rnt),
            10000 * 10**18,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        vm.stopPrank();
    }
    
    // 测试buyETH函数 - 用RNT购买ETH
    function testBuyETH() public {
        vm.startPrank(user);
        
        // 使用足够多的RNT来购买约1个ETH
        uint256 rntAmount = 10000 * 10**18;  // 使用10000 RNT
        uint256 minEthAmount = 0;
        
        rnt.approve(address(dex), rntAmount);
        
        uint256 rntBalanceBefore = rnt.balanceOf(user);
        uint256 ethBalanceBefore = user.balance;
        
        dex.buyETH(address(rnt), rntAmount, minEthAmount);
        
        uint256 rntBalanceAfter = rnt.balanceOf(user);
        uint256 ethBalanceAfter = user.balance;
        
        uint256 ethReceived = ethBalanceAfter - ethBalanceBefore;
        
        assertEq(rntBalanceBefore - rntBalanceAfter, rntAmount, "RNT amount should decrease");
        assertGt(ethReceived, 0, "ETH balance should increase");
        
        console.log("Sold RNT:", rntAmount / 1e18, "RNT");
        console.log("Received ETH:", ethReceived / 1e18, "ETH");
        console.log("Received ETH (wei):", ethReceived);
        
        vm.stopPrank();
    }
    
    // 测试sellETH函数 - 用ETH购买RNT
    function testSellETH() public {
        // 首先通过buyETH获取一些ETH
        testBuyETH();
        
        vm.startPrank(user);
        
        // 使用1 ETH购买RNT
        uint256 ethAmount = 1 ether;
        uint256 minRntAmount = 0;
        
        uint256 rntBalanceBefore = rnt.balanceOf(user);
        uint256 ethBalanceBefore = user.balance;
        
        dex.sellETH{value: ethAmount}(address(rnt), minRntAmount);
        
        uint256 rntBalanceAfter = rnt.balanceOf(user);
        uint256 ethBalanceAfter = user.balance;
        
        uint256 rntReceived = rntBalanceAfter - rntBalanceBefore;
        
        assertEq(ethBalanceBefore - ethBalanceAfter, ethAmount, "ETH amount should decrease");
        assertGt(rntReceived, 0, "RNT balance should increase");
        
        console.log("Sold ETH:", ethAmount / 1e18, "ETH");
        console.log("Received RNT:", rntReceived / 1e18, "RNT");
        console.log("Received RNT (wei):", rntReceived);
        
        vm.stopPrank();
    }
    
    // 测试错误情况 - 发送0 ETH
    function testSellZeroETH() public {
        vm.startPrank(user);
        
        // 尝试发送0 ETH
        vm.expectRevert("Must send ETH");
        dex.sellETH(address(rnt), 0);
        
        vm.stopPrank();
    }
    
    // 测试错误情况 - 发送0 RNT
    function testBuyETHWithZeroRNT() public {
        vm.startPrank(user);
        
        // 尝试发送0 RNT
        vm.expectRevert("Must sell tokens");
        dex.buyETH(address(rnt), 0, 0);
        
        vm.stopPrank();
    }
    
    // 测试错误情况 - 未授权代币
    function testBuyETHWithoutApproval() public {
        vm.startPrank(user);
        
        uint256 rntAmount = 1000 * 10**18;
        
        // 不授权Dex使用RNT代币
        // 预期会失败，因为没有授权
        vm.expectRevert();
        dex.buyETH(address(rnt), rntAmount, 0);
        
        vm.stopPrank();
    }
    
    // 测试最小兑换量限制
    function testSellETHWithMinimumAmount() public {
        vm.startPrank(user);
        
        uint256 ethAmount = 1 ether;
        // 设置一个非常高的最小RNT数量，预期会失败
        uint256 minRntAmount = 1000000 * 10**18;
        
        // 预期会失败，因为最小兑换量太高
        vm.expectRevert();
        dex.sellETH{value: ethAmount}(address(rnt), minRntAmount);
        
        vm.stopPrank();
    }
    
    // 测试最小兑换量限制
    function testBuyETHWithMinimumAmount() public {
        vm.startPrank(user);
        
        uint256 rntAmount = 1000 * 10**18;
        // 设置一个非常高的最小ETH数量，预期会失败
        uint256 minEthAmount = 1000 ether;
        
        // 授权Dex使用RNT代币
        rnt.approve(address(dex), rntAmount);
        
        // 预期会失败，因为最小兑换量太高
        vm.expectRevert();
        dex.buyETH(address(rnt), rntAmount, minEthAmount);
        
        vm.stopPrank();
    }
}

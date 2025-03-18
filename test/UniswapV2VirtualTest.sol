// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Router.sol";
import "../src/UniswapV2Pair.sol";
import "../src/WETH9.sol";
import "../src/MyERC20Token.sol";
import "../src/interfaces/IUniswapV2Pair.sol";

contract UniswapV2VirtualTest is Test {
    UniswapV2Factory public factory;
    UniswapV2Router public router;
    WETH9 public weth;
    MyERC20Token public tokenA;
    MyERC20Token public tokenB;
    
    address public user = address(1);
    uint256 public constant INITIAL_AMOUNT = 1000000 * 10**18;
    
    function setUp() public {
        // Deploy WETH9
        weth = new WETH9();
        
        // Deploy two ERC20 tokens
        tokenA = new MyERC20Token("Token A", "TKNA");
        tokenB = new MyERC20Token("Token B", "TKNB");
        
        // Mint tokens for test user
        tokenA.mint(user, INITIAL_AMOUNT);
        tokenB.mint(user, INITIAL_AMOUNT);
        
        // Deploy Factory
        factory = new UniswapV2Factory(address(0));
        
        // Deploy Router
        router = new UniswapV2Router(address(factory), address(weth));
        
        // Give user some ETH
        vm.deal(user, 100 ether);
    }
    
    function testFactoryCreatePair() public {
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        assertNotEq(pairAddress, address(0), "Pair creation failed");
        
        address retrievedPair = factory.getPair(address(tokenA), address(tokenB));
        assertEq(retrievedPair, pairAddress, "Retrieved pair address does not match");
        
        assertEq(factory.allPairsLength(), 1, "Incorrect number of pairs");
    }
    
    function testAddLiquidity() public {
        vm.startPrank(user);
        
        // Approve Router to use tokens
        tokenA.approve(address(router), INITIAL_AMOUNT);
        tokenB.approve(address(router), INITIAL_AMOUNT);
        
        // Add liquidity
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 2000 * 10**18;
        
        (uint256 actualA, uint256 actualB, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        assertEq(actualA, amountA, "Incorrect amount of tokenA added");
        assertEq(actualB, amountB, "Incorrect amount of tokenB added");
        assertGt(liquidity, 0, "Liquidity tokens amount should be greater than 0");
        
        // Check pair address
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        assertNotEq(pairAddress, address(0), "Pair address should not be zero");
        
        // Check user's liquidity token balance
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        assertEq(pair.balanceOf(user), liquidity, "User's liquidity token balance is incorrect");
        
        vm.stopPrank();
    }
    
    function testAddLiquidityETH() public {
        vm.startPrank(user);
        
        // Approve Router to use tokens
        tokenA.approve(address(router), INITIAL_AMOUNT);
        
        // Add ETH liquidity
        uint256 amountToken = 1000 * 10**18;
        uint256 amountETH = 5 ether;
        
        (uint256 actualToken, uint256 actualETH, uint256 liquidity) = router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountToken,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        assertEq(actualToken, amountToken, "Incorrect amount of token added");
        assertEq(actualETH, amountETH, "Incorrect amount of ETH added");
        assertGt(liquidity, 0, "Liquidity tokens amount should be greater than 0");
        
        // Check pair address
        address pairAddress = factory.getPair(address(tokenA), address(weth));
        assertNotEq(pairAddress, address(0), "Pair address should not be zero");
        
        // Check user's liquidity token balance
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        assertEq(pair.balanceOf(user), liquidity, "User's liquidity token balance is incorrect");
        
        vm.stopPrank();
    }
    
    function testSwapExactTokensForTokens() public {
        // First add liquidity
        vm.startPrank(user);
        
        tokenA.approve(address(router), INITIAL_AMOUNT);
        tokenB.approve(address(router), INITIAL_AMOUNT);
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10000 * 10**18,
            10000 * 10**18,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        // Execute token swap
        uint256 amountIn = 100 * 10**18;
        uint256 amountOutMin = 90 * 10**18; // Allow 10% slippage
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256 tokenBBalanceBefore = tokenB.balanceOf(user);
        
        router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenBBalanceAfter = tokenB.balanceOf(user);
        
        assertGt(tokenBBalanceAfter, tokenBBalanceBefore, "Token balance should increase after swap");
        
        vm.stopPrank();
    }
    
    function testSwapTokensForExactTokens() public {
        // First add liquidity
        vm.startPrank(user);
        
        tokenA.approve(address(router), INITIAL_AMOUNT);
        tokenB.approve(address(router), INITIAL_AMOUNT);
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10000 * 10**18,
            10000 * 10**18,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        // Execute token swap
        uint256 amountOut = 100 * 10**18;
        uint256 amountInMax = 120 * 10**18; // Allow maximum payment of 120 tokens
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint256 tokenABalanceBefore = tokenA.balanceOf(user);
        uint256 tokenBBalanceBefore = tokenB.balanceOf(user);
        
        router.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenABalanceAfter = tokenA.balanceOf(user);
        uint256 tokenBBalanceAfter = tokenB.balanceOf(user);
        
        assertLt(tokenABalanceAfter, tokenABalanceBefore, "Token A balance should decrease");
        assertEq(tokenBBalanceAfter - tokenBBalanceBefore, amountOut, "Should receive exact amount of token B");
        
        vm.stopPrank();
    }
    
    function testSwapExactETHForTokens() public {
        // First add ETH liquidity
        vm.startPrank(user);
        
        tokenA.approve(address(router), INITIAL_AMOUNT);
        
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            10000 * 10**18,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        // Execute ETH to token swap
        uint256 amountOutMin = 90 * 10**18; // Minimum expected token amount
        uint256 ethAmount = 1 ether;
        
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        
        uint256 tokenBalanceBefore = tokenA.balanceOf(user);
        
        router.swapExactETHForTokens{value: ethAmount}(
            amountOutMin,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenBalanceAfter = tokenA.balanceOf(user);
        
        assertGt(tokenBalanceAfter, tokenBalanceBefore, "Token balance should increase");
        
        vm.stopPrank();
    }
    
    function testSwapTokensForExactETH() public {
        // First add ETH liquidity
        vm.startPrank(user);
        
        tokenA.approve(address(router), INITIAL_AMOUNT);
        
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            10000 * 10**18,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        // Execute token to ETH swap
        uint256 ethAmountOut = 1 ether;
        uint256 tokenAmountInMax = 1200 * 10**18;
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);
        
        uint256 ethBalanceBefore = user.balance;
        
        router.swapTokensForExactETH(
            ethAmountOut,
            tokenAmountInMax,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 ethBalanceAfter = user.balance;
        
        assertEq(ethBalanceAfter - ethBalanceBefore, ethAmountOut, "Should receive exact amount of ETH");
        
        vm.stopPrank();
    }
    
    function testSwapExactTokensForETH() public {
        // First add ETH liquidity
        vm.startPrank(user);
        
        tokenA.approve(address(router), INITIAL_AMOUNT);
        
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            10000 * 10**18,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        // Execute token to ETH swap
        uint256 tokenAmount = 100 * 10**18;
        uint256 ethAmountOutMin = 0.09 ether; // Minimum expected ETH amount
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);
        
        uint256 ethBalanceBefore = user.balance;
        
        router.swapExactTokensForETH(
            tokenAmount,
            ethAmountOutMin,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 ethBalanceAfter = user.balance;
        
        assertGt(ethBalanceAfter, ethBalanceBefore, "ETH balance should increase");
        
        vm.stopPrank();
    }
    
    function testSwapETHForExactTokens() public {
        // First add ETH liquidity
        vm.startPrank(user);
        
        tokenA.approve(address(router), INITIAL_AMOUNT);
        
        router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            10000 * 10**18,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        // Execute ETH to token swap
        uint256 tokenAmountOut = 100 * 10**18;
        uint256 ethAmountInMax = 1 ether;
        
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        
        uint256 tokenBalanceBefore = tokenA.balanceOf(user);
        
        router.swapETHForExactTokens{value: ethAmountInMax}(
            tokenAmountOut,
            path,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenBalanceAfter = tokenA.balanceOf(user);
        
        assertEq(tokenBalanceAfter - tokenBalanceBefore, tokenAmountOut, "Should receive exact amount of tokens");
        
        vm.stopPrank();
    }
    
    function testRemoveLiquidity() public {
        // First add liquidity
        vm.startPrank(user);
        
        tokenA.approve(address(router), INITIAL_AMOUNT);
        tokenB.approve(address(router), INITIAL_AMOUNT);
        
        (,, uint256 liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 * 10**18,
            1000 * 10**18,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        // Get pair address
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        
        // Approve Router to use liquidity tokens
        pair.approve(address(router), liquidity);
        
        uint256 tokenABalanceBefore = tokenA.balanceOf(user);
        uint256 tokenBBalanceBefore = tokenB.balanceOf(user);
        
        // Remove liquidity
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenABalanceAfter = tokenA.balanceOf(user);
        uint256 tokenBBalanceAfter = tokenB.balanceOf(user);
        
        assertEq(tokenABalanceAfter - tokenABalanceBefore, amountA, "Incorrect amount of tokenA returned");
        assertEq(tokenBBalanceAfter - tokenBBalanceBefore, amountB, "Incorrect amount of tokenB returned");
        assertEq(pair.balanceOf(user), 0, "User's liquidity token balance should be 0");
        
        vm.stopPrank();
    }
    
    function testRemoveLiquidityETH() public {
        // First add ETH liquidity
        vm.startPrank(user);
        
        tokenA.approve(address(router), INITIAL_AMOUNT);
        
        (,, uint256 liquidity) = router.addLiquidityETH{value: 5 ether}(
            address(tokenA),
            1000 * 10**18,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        // Get pair address
        address pairAddress = factory.getPair(address(tokenA), address(weth));
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        
        // Approve Router to use liquidity tokens
        pair.approve(address(router), liquidity);
        
        uint256 tokenBalanceBefore = tokenA.balanceOf(user);
        uint256 ethBalanceBefore = user.balance;
        
        // Remove liquidity
        (uint256 amountToken, uint256 amountETH) = router.removeLiquidityETH(
            address(tokenA),
            liquidity,
            0,
            0,
            user,
            block.timestamp + 3600
        );
        
        uint256 tokenBalanceAfter = tokenA.balanceOf(user);
        uint256 ethBalanceAfter = user.balance;
        
        assertEq(tokenBalanceAfter - tokenBalanceBefore, amountToken, "Incorrect amount of token returned");
        assertEq(ethBalanceAfter - ethBalanceBefore, amountETH, "Incorrect amount of ETH returned");
        assertEq(pair.balanceOf(user), 0, "User's liquidity token balance should be 0");
        
        vm.stopPrank();
    }
} 
// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Router.sol";
import "../src/UniswapV2Pair.sol";
import "../src/WETH9.sol";
import "../src/MyERC20Token.sol";

contract UniswapV2LiveTest is Test {
    // Updated contract addresses
    address constant WETH_ADDRESS = 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853;
    address constant TOKEN_A_ADDRESS = 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6;
    address constant TOKEN_B_ADDRESS = 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318;
    address constant FACTORY_ADDRESS = 0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0;
    address constant ROUTER_ADDRESS = 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82;
    
    // Contract instances
    WETH9 weth;
    MyERC20Token tokenA;
    MyERC20Token tokenB;
    UniswapV2Factory factory;
    UniswapV2Router router;
    
    // Test user address (Anvil's first account)
    address user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    
    function setUp() public {
        // Fork Anvil at a specific block
        vm.createSelectFork("http://localhost:8545");
        
        // Connect to deployed contracts
        weth = WETH9(payable (WETH_ADDRESS));
        tokenA = MyERC20Token(TOKEN_A_ADDRESS);
        tokenB = MyERC20Token(TOKEN_B_ADDRESS);
        factory = UniswapV2Factory(FACTORY_ADDRESS);
        router = UniswapV2Router(payable(ROUTER_ADDRESS));
        
        // Impersonate the user account
        vm.startPrank(user);
    }
    
    function testCreatePair() public {
        // Create a pair for TokenA and TokenB
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        console.log("Pair created at address:", pairAddress);
        
        // Verify the pair exists
        address retrievedPairAddress = factory.getPair(address(tokenA), address(tokenB));
        assertEq(retrievedPairAddress, pairAddress, "Pair address mismatch");
        
        // Get the pair contract
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        
        // Verify pair token addresses
        assertEq(pair.token0(), address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB), "Token0 mismatch");
        assertEq(pair.token1(), address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA), "Token1 mismatch");
    }
    
    function testAddLiquidity() public {
        // Approve tokens for router
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        
        // Add liquidity
        uint amountA = 1000 * 10**18; // 1000 tokens
        uint amountB = 2000 * 10**18; // 2000 tokens
        
        (uint amountAAdded, uint amountBAdded, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0, // min amount A
            0, // min amount B
            user, // recipient of LP tokens
            block.timestamp + 3600 // deadline
        );
        
        console.log("Added liquidity:");
        console.log("- Token A amount:", amountAAdded);
        console.log("- Token B amount:", amountBAdded);
        console.log("- LP tokens received:", liquidity);
        
        // Get the pair address
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        
        // Verify LP token balance
        assertEq(pair.balanceOf(user), liquidity, "LP token balance mismatch");
        
        // Verify reserves
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        console.log("Pair reserves:");
        console.log("- Reserve0:", uint(reserve0));
        console.log("- Reserve1:", uint(reserve1));
        
        assertTrue(reserve0 > 0 && reserve1 > 0, "Reserves should be positive");
    }
    
    function testSwapTokens() public {
        // First add liquidity if not already done
        if (factory.getPair(address(tokenA), address(tokenB)) == address(0)) {
            testAddLiquidity();
        }
        
        // Get initial balances
        uint initialBalanceA = tokenA.balanceOf(user);
        uint initialBalanceB = tokenB.balanceOf(user);
        
        // Approve tokens for router
        tokenA.approve(address(router), type(uint256).max);
        
        // Swap 10 TokenA for TokenB
        uint amountIn = 10 * 10**18; // 10 tokens
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0, // min amount out
            path,
            user,
            block.timestamp + 3600 // deadline
        );
        
        console.log("Swap results:");
        console.log("- Token A in:", amounts[0]);
        console.log("- Token B out:", amounts[1]);
        
        // Verify balances changed correctly
        assertEq(tokenA.balanceOf(user), initialBalanceA - amounts[0], "Token A balance mismatch");
        assertEq(tokenB.balanceOf(user), initialBalanceB + amounts[1], "Token B balance mismatch");
    }
    
    function testRemoveLiquidity() public {
        // First add liquidity if not already done
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        if (pairAddress == address(0)) {
            testAddLiquidity();
            pairAddress = factory.getPair(address(tokenA), address(tokenB));
        }
        
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        
        // Get initial balances
        uint initialBalanceA = tokenA.balanceOf(user);
        uint initialBalanceB = tokenB.balanceOf(user);
        uint lpBalance = pair.balanceOf(user);
        
        console.log("Initial LP token balance:", lpBalance);
        
        // Approve LP tokens for router
        pair.approve(address(router), lpBalance);
        
        // Remove half of the liquidity
        uint liquidityToRemove = lpBalance / 2;
        
        (uint amountA, uint amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidityToRemove,
            0, // min amount A
            0, // min amount B
            user,
            block.timestamp + 3600 // deadline
        );
        
        console.log("Removed liquidity:");
        console.log("- LP tokens burned:", liquidityToRemove);
        console.log("- Token A received:", amountA);
        console.log("- Token B received:", amountB);
        
        // Verify LP token balance decreased
        assertEq(pair.balanceOf(user), lpBalance - liquidityToRemove, "LP token balance mismatch");
        
        // Verify token balances increased
        assertEq(tokenA.balanceOf(user), initialBalanceA + amountA, "Token A balance mismatch");
        assertEq(tokenB.balanceOf(user), initialBalanceB + amountB, "Token B balance mismatch");
    }
    
    function testCompleteFlow() public {
        // Test the entire flow: create pair, add liquidity, swap, remove liquidity
        testCreatePair();
        testAddLiquidity();
        testSwapTokens();
        testRemoveLiquidity();
    }
} 
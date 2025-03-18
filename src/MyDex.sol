// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./MyERC20Token.sol";

contract MyDex {
    IUniswapV2Factory public immutable factory;
    IUniswapV2Router public immutable router;
    address public immutable WETH;

    constructor(address _factory, address _router, address _weth) {
        factory = IUniswapV2Factory(_factory);
        router = IUniswapV2Router(_router);
        WETH = _weth;
    }

    // Create a new liquidity pool for a token with ETH
    function createPair(address token) external returns (address) {
        return factory.createPair(token, WETH);
    }

    // Add liquidity to a token-ETH pair
    function addLiquidity(
        address token,
        uint amountToken,
        uint amountETH,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountTokenOut, uint amountETHOut, uint liquidity) {
        MyERC20Token(token).transferFrom(msg.sender, address(this), amountToken);
        MyERC20Token(token).approve(address(router), amountToken);

        require(msg.value >= amountETH, "Insufficient ETH sent");

        (amountTokenOut, amountETHOut, liquidity) = router.addLiquidityETH{value: amountETH}(
            token,
            amountToken,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );

        // Refund excess ETH if any
        if (msg.value > amountETH) {
            (bool success, ) = msg.sender.call{value: msg.value - amountETH}("");
            require(success, "ETH refund failed");
        }

        // Refund excess tokens if any
        if (amountToken > amountTokenOut) {
            MyERC20Token(token).transfer(msg.sender, amountToken - amountTokenOut);
        }

        return (amountTokenOut, amountETHOut, liquidity);
    }

    // Remove liquidity from a token-ETH pair
    function removeLiquidity(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH) {
        address pair = factory.getPair(token, WETH);
        MyERC20Token(pair).transferFrom(msg.sender, address(this), liquidity);
        MyERC20Token(pair).approve(address(router), liquidity);

        return router.removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    // Swap tokens for ETH
    function swapTokensForETH(
        address token,
        uint amountIn,
        uint amountOutMin,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        MyERC20Token(token).transferFrom(msg.sender, address(this), amountIn);
        MyERC20Token(token).approve(address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WETH;

        return router.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    // Swap ETH for tokens
    function swapETHForTokens(
        address token,
        uint amountOutMin,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = token;

        return router.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    // Get the amount of tokens that would be received for a given amount of ETH
    function getETHToTokenAmount(address token, uint amountETH) external view returns (uint) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = token;

        uint[] memory amounts = router.getAmountsOut(amountETH, path);
        return amounts[1];
    }

    // Get the amount of ETH that would be received for a given amount of tokens
    function getTokenToETHAmount(address token, uint amountToken) external view returns (uint) {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WETH;

        uint[] memory amounts = router.getAmountsOut(amountToken, path);
        return amounts[1];
    }

    /**
     * @dev 卖出ETH，兑换成 buyToken(RNT)
     * @param buyToken 兑换的目标代币地址(RNT)
     * @param minBuyAmount 要求最低兑换到的 buyToken 数量
     */
    function sellETH(address buyToken, uint256 minBuyAmount) external payable {
        require(msg.value > 0, "Must send ETH");
        
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = buyToken;
        
        router.swapExactETHForTokens{value: msg.value}(
            minBuyAmount,
            path,
            msg.sender,
            block.timestamp + 600
        );
    }
    
    /**
     * @dev 买入ETH，用 sellToken 兑换(RNT)
     * @param sellToken 出售的代币地址(RNT)
     * @param sellAmount 出售的代币数量
     * @param minBuyAmount 要求最低兑换到的ETH数量
     */
    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external {
        require(sellAmount > 0, "Must sell tokens");
        
        MyERC20Token(sellToken).transferFrom(msg.sender, address(this), sellAmount);
        MyERC20Token(sellToken).approve(address(router), sellAmount);
        
        address[] memory path = new address[](2);
        path[0] = sellToken;
        path[1] = WETH;
        
        router.swapExactTokensForETH(
            sellAmount,
            minBuyAmount,
            path,
            msg.sender,
            block.timestamp + 600
        );
    }

    // Fallback function to receive ETH
    receive() external payable {}
} 
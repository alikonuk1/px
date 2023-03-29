// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITreasury {
    function moveOut(address token, address to, uint256 amount) external;

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./utils/Ownable.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ISwapRouter.sol";

contract Treasury is Ownable {
    address public px;
    address public swapRouter;

    modifier onlyPx() {
        _checkPx();
        _;
    }

    function _checkPx() internal view {
        require(msg.sender == px, "!px");
    }

    function setPx(address px_) public onlyOwner {
        px = px_;
    }

    function setRouter(address swapRouter_) public onlyOwner {
        swapRouter = swapRouter_;
    }

    function moveOut(address token, address to, uint256 amount) public onlyPx {
        IERC20(token).transfer(to, amount);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn)
        external
        onlyPx
        returns (uint256 amountOut)
    {
        /*         IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn); */
        IERC20(tokenIn).approve(address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        amountOut = ISwapRouter(swapRouter).exactInputSingle(params);
    }
}

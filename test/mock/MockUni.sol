// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20} from "../../src/interfaces/IERC20.sol";

contract MockUni {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external returns (uint256 amountOut) {
        require(params.tokenIn != address(0) && params.tokenOut != address(0), "Invalid token addresses");
        require(params.amountIn > 0, "Amount in should be greater than 0");
        require(params.recipient != address(0), "Invalid recipient address");

        // You can add your own logic here for calculating the output amount based on the input amount.
        // For simplicity, we'll just return the input amount multiplied by a fixed rate.
        uint256 rate = 2;
        amountOut = params.amountIn * rate;

        // Simulate the token transfer
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        IERC20(params.tokenOut).transfer(params.recipient, amountOut);

        return amountOut;
    }
}

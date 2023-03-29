// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./interfaces/IERC20.sol";

contract Vault {

    address public px;

    modifier onlyPx() {
        _checkPx();
        _;
    }

    constructor(address px_){
        px = px_;
    }

    function _checkPx() internal view {
        require(msg.sender == px, "!px");
    }

    function moveOut(address token, address to, uint256 amount) public onlyPx {
        IERC20(token).transfer(to, amount);
    }
}
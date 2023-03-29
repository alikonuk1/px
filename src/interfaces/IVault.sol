// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IVault {
    function moveOut(address token, address to, uint256 amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IErrors {
    error DUST();
    error ZERO();
    error REENTRANCY();
    error NO_POSITION();
    error MAX_LEVERAGE();
    error NOT_UNDERMARGINED();
    error OPEN_POSITION_LEFT();
}

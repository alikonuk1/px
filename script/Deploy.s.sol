// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import {Px} from "src/Px.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 usdc = new MockERC20( "Usdc", "USDC", 6);
        MockERC20 weth = new MockERC20( "Weth", "WETH", 18);

        Px px = new Px(address(0), address(usdc), address(weth), address(0));

        vm.stopBroadcast();
    }
}

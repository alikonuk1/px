/* // SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import {Px} from "src/Px.sol";
import {Treasury} from "src/Treasury.sol";
import {MockUni} from "test/mock/MockUni.sol";
import {MockERC20} from "test/mock/MockERC20.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 usdc = new MockERC20( "Usdc", "USDC", 6);
        MockERC20 weth = new MockERC20( "Weth", "WETH", 18);

        proxy = new MockProxy(api3ServerV1);
        proxy.mock(1800, 1);

        MockUni uni = new MockUni();

        // deploy treasury
        treasury = new Treasury();

        Px px = new Px(address(proxy), address(usdc), address(weth), address(treasury));

        vm.stopBroadcast();
    }
}
 */
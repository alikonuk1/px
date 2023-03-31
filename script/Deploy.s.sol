// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import {Px} from "src/Px.sol";
import {Treasury} from "src/Treasury.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockUni} from "test/mock/MockUni.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 usdc = new MockERC20( "Usdc", "USDC", 6);
        MockERC20 weth = new MockERC20( "Weth", "WETH", 18);

        MockUni uni = new MockUni( 
            0x94C10721Bc55E81E40E5Db92060335374F32546b, 
            address(usdc), 
            address(weth));

        Treasury treasury = new Treasury();

        Px px = new Px(
            0x94C10721Bc55E81E40E5Db92060335374F32546b, 
            address(usdc), 
            address(weth),
            address(treasury));

        treasury.setPx(address(px));

        vm.stopBroadcast();
    }
}

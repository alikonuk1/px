// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import {Px} from "src/Px.sol";
import {MockERC20} from "test/mock/MockERC20.sol";
import {MockUni} from "test/mock/MockUni.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        /*         MockERC20 usdc = new MockERC20( "Usdc", "USDC", 6);
        MockERC20 weth = new MockERC20( "Weth", "WETH", 18); */

        Px px = new Px(
            0x94C10721Bc55E81E40E5Db92060335374F32546b, 
            0xe32BfD288d21Eea6022a27E40aADcE0A9612Dc10, 
            0x80766F7635665e7100c527E716768A53ABda51ba, 
            0xeA56A438A3098d5bBEF3Bf6F4bfaE6a754c26661);

        vm.stopBroadcast();
    }
}

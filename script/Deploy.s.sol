// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Script.sol";
import {Px} from "src/Px.sol";
import {Treasury} from "src/Treasury.sol";
import {MockERC20v2} from "test/mock/MockERC20v2.sol";
import {MockUni} from "test/mock/MockUni.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockERC20v2 usdc = new MockERC20v2( "Usdc", "USDC", 6);
        MockERC20v2 weth = new MockERC20v2( "Weth", "WETH", 18);

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

        /*         Px px = new Px(
            0x94C10721Bc55E81E40E5Db92060335374F32546b, 
            0xfC5E517AE25AdbB858fCB7BbB1971e54F2f3A6a9, 
            0x5D96e3AaA644C59847e19DA669de9BCe74Dfbb85,
            0xbcA610dDEa432cc2b888c4B70205a922A5F15095); */

        treasury.setPx(address(px));
        treasury.setRouter(address(uni));

        usdc.mint(0x2B68407d77B044237aE7f99369AA0347Ca44B129, 10_000 * 10 ** 6);
        weth.mint(0x2B68407d77B044237aE7f99369AA0347Ca44B129, 10_000 * 10 ** 18);

        usdc.mint(address(uni), 10_000 * 10 ** 6);
        weth.mint(address(uni), 10_000 * 10 ** 18);

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { Transparent } from "../src/Transparent.sol";
import { DefiDolly } from "../src/DefiDolly.sol";

// forge script DefiDollyScript --rpc-url https://rpc.tenderly.co/fork/7544f53a-f939-4181-a42a-914fca1dec13 --broadcast
// implement address:  0x61b3c60bCD092d71F656a7ACb9B9b24cc47cEC50
// transperant address:  0x9b0fd492dDC47Fe036ad4cD66c726291749FC573

interface ITransparentUpgradeableProxy {
    function admin() external view returns (address);

    function implementation() external view returns (address);

    function changeAdmin(address) external;

    function upgradeTo(address) external;

    function upgradeToAndCall(address, bytes memory) external payable;
}

contract DefiDollyScript is Script {
  function setUp() public {}
  function run() external {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    // console.log(vm.envUint("PRIVATE_KEY"));
  
    // deploy contract
    // 1. 先得到 Imple contract address 
    DefiDolly defiDolly = new DefiDolly();
    // 2. 再部署 Transparent contract
    Transparent transparent = new Transparent(address(defiDolly));
    DefiDolly defiDollyProx = DefiDolly(payable(address(transparent)));
    defiDollyProx.initialize(true);

    // upgrade contract
    // DefiDolly defiDolly = new DefiDolly();
    // ITransparentUpgradeableProxy transparent = ITransparentUpgradeableProxy(0xFb74Fc2d259A479Ff80EA91E07988cF12FdE1974);

    // transparent.upgradeTo(address(defiDolly));

    // 1. 先得到 Imple contract address 
    console.log("implement address: ", address(defiDolly));
    // 2. 再部署 Transparent contract
    console.log("transperant address: ", address(transparent));

    vm.stopBroadcast();
  }
}
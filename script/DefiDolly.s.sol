// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { Transparent } from "../src/Transparent.sol";
import { DefiDolly } from "../src/DefiDolly.sol";

// forge script DefiDollyScript --rpc-url https://rpc.tenderly.co/fork/7544f53a-f939-4181-a42a-914fca1dec13 --broadcast
// implement address:  0xFc283CCb60E30deBA9211A112BF90b8a6874C2EB
// transperant address:  0x2130F61DF0b41C0276d67c9ef2001d2826bc9C3c

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
    // console.log(vm.envUint("PRIVATE_KEY"));
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
  
    // deploy contract
    // DefiDolly defiDolly = new DefiDolly();
    Transparent transparent = new Transparent(0xFc283CCb60E30deBA9211A112BF90b8a6874C2EB);
    
    

    // upgrade contract
    // DefiDolly defiDolly = new DefiDolly();
    // ITransparentUpgradeableProxy transparent = ITransparentUpgradeableProxy(0xFb74Fc2d259A479Ff80EA91E07988cF12FdE1974);

    // transparent.upgradeTo(address(defiDolly));

    // console.log("implement address: ", address(defiDolly));
    console.log("transperant address: ", address(transparent));

    vm.stopBroadcast();
  }
}
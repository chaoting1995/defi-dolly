// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "forge-std/Script.sol";
// import { Transparent } from "../src/Transparent.sol";
// import { DefiDolly } from "../src/DefiDolly.sol";

// // forge script DefiDollyScript1 --rpc-url https://rpc.tenderly.co/fork/7544f53a-f939-4181-a42a-914fca1dec13 --broadcast

// contract DefiDollyScript1 is Script {
//   function setUp() public {}
//   function run() external {
//     vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
      
//     // deploy implement contract
//     DefiDolly defiDolly = new DefiDolly();
//     console.log("implement address: ", address(defiDolly));
//     // implement address:  0x61b3c60bCD092d71F656a7ACb9B9b24cc47cEC50

//     vm.stopBroadcast();
//   }
// }
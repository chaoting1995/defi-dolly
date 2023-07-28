// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "forge-std/Script.sol";
// import { Transparent } from "../src/Transparent.sol";
// import { DefiDolly } from "../src/DefiDolly.sol";

// // forge script DefiDollyScript2 --rpc-url https://rpc.tenderly.co/fork/7544f53a-f939-4181-a42a-914fca1dec13 --broadcast

// contract DefiDollyScript2 is Script {
//   function setUp() public {}
//   function run() external {
//     vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
  
//     address imple = 0x61b3c60bCD092d71F656a7ACb9B9b24cc47cEC50;

//     // deploy transparent contract
//     Transparent transparent = new Transparent(imple);    
//     DefiDolly defiDollyProx = DefiDolly(payable(address(transparent)));
//     defiDollyProx.initialize();

//     console.log("transperant address: ", address(transparent));
//     // transperant address:  0x9b0fd492dDC47Fe036ad4cD66c726291749FC573
//     vm.stopBroadcast();
//   }
// }
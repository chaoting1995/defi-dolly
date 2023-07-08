// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import { TransparentUpgradeableProxy } from "./TransparentUpgradeableProxy.sol";

contract Transparent is TransparentUpgradeableProxy {
    
    constructor(address _implementation) TransparentUpgradeableProxy(_implementation, msg.sender, "") {
    }

}
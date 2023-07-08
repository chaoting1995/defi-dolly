// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IWERC20 is IERC20{
    function withdraw(uint wad) external;
}
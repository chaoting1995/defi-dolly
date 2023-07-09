// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface STETH is IERC20{
    function submit(address _referral) external payable returns (uint256);
}

interface WSTETH is IERC20{
    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256); // send ETH amount(_stETHAmount) return wstETH amount
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256); // send wstETH amount(_wstETHAmount) return stETH amount
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}
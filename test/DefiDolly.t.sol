// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../src/DefiDolly.sol";
import "../src/Transparent.sol";
import { STETH, WSTETH } from "../src/interfaces/ILido.sol";
import { IWERC20 } from "../src/interfaces/IWERC20.sol";
import { ICompoundV3 } from "../src/interfaces/ICompoundV3.sol";


contract DefiDollyTest is Test {
    DefiDolly public defiDolly;
    Transparent public transparent;
    IWERC20 public wETH = IWERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    STETH public stETH = STETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    WSTETH public wstETH = WSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    ICompoundV3 public compoundV3 = ICompoundV3(0xA17581A9E3356d9A858b789D68B4d866e593aE94);
    // address ZEROAddress = 0x0000000000000000000000000000000000000000;
    address public owner = makeAddr("owner");
    address public stake1 = makeAddr("stake1");
    address public stake2 = makeAddr("stake2");

    struct StakeOrder {
        uint256 stakedETH;
        uint256 stakedstETH;
        uint256 stakedwstETH;
        uint32 leverage;
        uint256 stakeTime;
    }

    function setUp() public {
        vm.createSelectFork("mainnet"); // 17441862 - 250000: 88, 17441862 - 15000: 89
        // vm.createSelectFork("test");
        vm.startPrank(owner);
        defiDolly = new DefiDolly();
        transparent = new Transparent(address(defiDolly));
        defiDolly = DefiDolly(payable(address(transparent)));
        defiDolly.initialize(true);
        // uint bloockNumber = block.number;
        // vm.roll(blockNumber + 100);
        deal(stake1, 100 ether);
        deal(stake2, 100 ether);
        deal(address(defiDolly), 100 ether);
        vm.label(stake1, "stake1");
        vm.label(stake2, "stake1");
        vm.stopPrank();
    }

    function testStakeETH() external {
        // vm.startPrank(address(defiDolly));
        // (bool sent,) = address(wETH).call{value: 50 ether}("");
        // require(sent, "Failed to send Ether");
        // require(wETH.balanceOf(address(defiDolly)) > 10 ether);
        // vm.stopPrank();
        vm.startPrank(stake1);
        defiDolly.stake{ value: 1 ether }(address(0x0));
        (uint256 totalStakedETH, uint256 totalStakedstETH, uint256 totalStakedwstETH, address refferal, uint256 runTime, ) = defiDolly.accounts(stake1);
        console.log("stake1 total stake ETH amount:", totalStakedETH);
        console.log("stake1 total stake stETH amount:", totalStakedstETH);
        console.log("stake1 total stake wstETH amount:", totalStakedwstETH);
        console.log("stake1 refferal:", refferal);
        console.log("stake1 runTime:", runTime);
        console.log("protocol supply in compound:", compoundV3.collateralBalanceOf(address(defiDolly), address(wstETH)));
        console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));
        (uint256 stakedETH, uint256 stakedstETH, uint256 stakedwstETH, uint256 supply, uint256 borrow, uint32 leverage, uint256 temp) = defiDolly.getStakeOrder(stake1, 0);
        console.log("stake1 stake ETH amount:", stakedETH);
        console.log("stake1 stake stETH amount:", stakedstETH);
        console.log("stake1 stake wstETH amount:", stakedwstETH);
        console.log("stake1 supply amount:", supply);
        console.log("stake1 borrow amount:", borrow);
        console.log("stake1 leverage:", leverage);
        console.log("stake1 stakeTime:", temp);
        vm.stopPrank();
        
    }

    function testStakestETH() external {
        vm.startPrank(stake2);
        (bool sent,) = address(stETH).call{value: 50 ether}("");
        require(sent, "Failed to send Ether");
        console.log("balance of stETH: ", stETH.balanceOf(stake2));
        stETH.approve(address(defiDolly), 1 ether);
        defiDolly.stakeSTETH(1 ether, address(stake1));
        (uint256 totalStakedETH, uint256 totalStakedstETH, uint256 totalStakedwstETH, address refferal, uint256 runTime, ) = defiDolly.accounts(stake2);
        console.log("stake2 total stake ETH amount:", totalStakedETH);
        console.log("stake2 total stake stETH amount:", totalStakedstETH);
        console.log("stake2 total stake wstETH amount:", totalStakedwstETH);
        console.log("stake2 refferal:", refferal);
        console.log("stake2 runTime:", runTime);
        console.log("protocol supply in compound:", compoundV3.collateralBalanceOf(address(defiDolly), address(wstETH)));
        console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));
        (uint256 stakedETH, uint256 stakedstETH, uint256 stakedwstETH, uint256 supply, uint256 borrow, uint32 leverage, uint256 temp) = defiDolly.getStakeOrder(stake2, 0);
        console.log("stake2 stake ETH amount:", stakedETH);
        console.log("stake2 stake stETH amount:", stakedstETH);
        console.log("stake2 stake wstETH amount:", stakedwstETH);
        console.log("stake2 supply amount:", supply);
        console.log("stake2 borrow amount:", borrow);
        console.log("stake2 leverage:", leverage);
        console.log("stake2 stakeTime:", temp);
        vm.stopPrank();
        
    }

    function testUnstakeETH() external {
        vm.startPrank(stake1);
        defiDolly.stake{ value: 1 ether }(address(0x0));
        uint stakeAmount = defiDolly.getAccountStakedAmount(stake1);
        uint unstakeAmountETH = defiDolly.unstake();
        console.log("unstakeAmountETH: ", unstakeAmountETH);
        // (uint256 totalStakedETH, uint256 totalStakedstETH, uint256 totalStakedwstETH, address refferal, uint256 stakeTime, uint256 runTime, ) = defiDolly.accounts(stake1);
        // console.log("stake1 total stake ETH amount:", totalStakedETH);
        // console.log("stake1 total stake stETH amount:", totalStakedstETH);
        // console.log("stake1 total stake wstETH amount:", totalStakedwstETH);
        // console.log("stake1 refferal:", refferal);
        // console.log("stake1 stakeTime:", stakeTime);
        // console.log("stake1 runTime:", runTime);
        // console.log("protocol supply in compound:", compoundV3.collateralBalanceOf(address(defiDolly), address(wstETH)));
        // console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));

        vm.stopPrank();
    }

    function testRefferal() external {
        vm.startPrank(stake1);
        defiDolly.stake{ value: 1 ether }(address(stake2));
        (address account, uint256 time, uint256 unstakeReward ) = defiDolly.getReferee(stake2, 0);
        console.log("stake2 account: ", account);
        console.log("stake2 time: ", time);
        console.log("stake2 unstakeReward: ", unstakeReward);
        vm.stopPrank();

        vm.startPrank(stake2);
        defiDolly.stake{ value: 1 ether }(address(stake1));
        (account, time, unstakeReward ) = defiDolly.getReferee(stake1, 0);
        console.log("stake1 account: ", account);
        console.log("stake1 time: ", time);
        console.log("stake1 unstakeReward: ", unstakeReward);
        vm.stopPrank();
    }

    

}


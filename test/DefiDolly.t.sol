// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

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
        // vm.createSelectFork("mainnet", 17441862 - 15000); // 17441862 - 250000: 88, 17441862 - 15000: 89
        vm.createSelectFork("mainnet");
        // vm.createSelectFork("test");
        vm.startPrank(owner);
        defiDolly = new DefiDolly();
        transparent = new Transparent(address(defiDolly));
        defiDolly = DefiDolly(payable(address(transparent)));
        defiDolly.initialize();
        deal(stake1, 100 ether);
        deal(stake2, 100 ether);
        deal(owner, 100 ether);
        vm.label(stake1, "stake1");
        vm.label(stake2, "stake2");
        vm.stopPrank();
    }

    function testStakeETH() external {
        vm.startPrank(stake1);
        defiDolly.stake{ value: 1 ether }(address(0x0));
        (uint256 totalStakedETH, uint256 totalStakedstETH, uint256 totalStakedwstETH, address refferal, uint256 claimedReward, uint256 runTime, ) = defiDolly.accounts(stake1);
        console.log("stake1 total stake ETH amount:", totalStakedETH);
        console.log("stake1 total stake stETH amount:", totalStakedstETH);
        console.log("stake1 total stake wstETH amount:", totalStakedwstETH);
        console.log("stake1 refferal:", refferal);
        console.log("stake1 claimedReward: ", claimedReward);
        console.log("stake1 runTime:", runTime);
        console.log("protocol supply in compound:", compoundV3.collateralBalanceOf(address(defiDolly), address(wstETH)));
        console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));
        (uint256 length, uint256 stakedETH, uint256 stakedstETH, uint256 stakedwstETH, uint256 supply, uint256 borrow, uint256 temp, bool isUnstaked) = defiDolly.getStakeOrder(stake1, 0);
        console.log("stake1 stake order length:", length);
        console.log("stake1 stake ETH amount:", stakedETH);
        console.log("stake1 stake stETH amount:", stakedstETH);
        console.log("stake1 stake wstETH amount:", stakedwstETH);
        console.log("stake1 supply amount:", supply);
        console.log("stake1 borrow amount:", borrow);
        console.log("stake1 stakeTime:", temp);
        console.log("stake1 isUnstaked:", isUnstaked);

        // console.log("getTotalEarn: ", uint(-defiDolly.getTotalEarn(stake1)));

        // defiDolly.setStToWst(873572188519528273);
        
        // console.log("getTotalEarn: ", uint(defiDolly.getTotalEarn(stake1)));
        vm.stopPrank();
        
    }

    function testStakestETH() external {
        vm.startPrank(stake2);
        (bool sent,) = address(stETH).call{value: 50 ether}("");
        require(sent, "Failed to send Ether");
        stETH.approve(address(defiDolly), 1 ether);
        defiDolly.stakeSTETH(1 ether, address(stake1));
        (uint256 totalStakedETH, uint256 totalStakedstETH, uint256 totalStakedwstETH, address refferal, uint256 claimedReward, uint256 runTime, ) = defiDolly.accounts(stake2);
        console.log("stake2 total stake ETH amount:", totalStakedETH);
        console.log("stake2 total stake stETH amount:", totalStakedstETH);
        console.log("stake2 total stake wstETH amount:", totalStakedwstETH);
        console.log("stake2 refferal:", refferal);
        console.log("stake1 claimedReward: ", claimedReward);
        console.log("stake2 runTime:", runTime);
        console.log("protocol supply in compound:", compoundV3.collateralBalanceOf(address(defiDolly), address(wstETH)));
        console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));
        (uint256 length, uint256 stakedETH, uint256 stakedstETH, uint256 stakedwstETH, uint256 supply, uint256 borrow, uint256 temp, bool isUnstaked) = defiDolly.getStakeOrder(stake2, 0);
        console.log("stake2 stake order length:", length);
        console.log("stake2 stake ETH amount:", stakedETH);
        console.log("stake2 stake stETH amount:", stakedstETH);
        console.log("stake2 stake wstETH amount:", stakedwstETH);
        console.log("stake2 supply amount:", supply);
        console.log("stake2 borrow amount:", borrow);
        console.log("stake2 stakeTime:", temp);
        console.log("stake2 isUnstaked:", isUnstaked);
        vm.stopPrank();
        
    }

    function testUnstakeETH() external {
        vm.startPrank(stake1);
        defiDolly.stake{ value: 1 ether }(address(0x0));
        console.log("protocol supply in compound:", compoundV3.collateralBalanceOf(address(defiDolly), address(wstETH)));
        console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));

        // defiDolly.setWstToSt(wstETH.getStETHByWstETH(1 ether) + 94399040735289);
        vm.roll(block.number + 10000);

        console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));
        uint unstakeAmountETH = defiDolly.unstake();
        console.log("unstakeAmountETH: ", unstakeAmountETH);
        (uint256 totalStakedETH, uint256 totalStakedstETH, uint256 totalStakedwstETH, address refferal, uint256 claimedReward, uint256 runTime, ) = defiDolly.accounts(stake1);
        console.log("stake1 total stake ETH amount:", totalStakedETH);
        console.log("stake1 total stake stETH amount:", totalStakedstETH);
        console.log("stake1 total stake wstETH amount:", totalStakedwstETH);
        console.log("stake1 refferal:", refferal);
        console.log("stake1 claimedReward: ", claimedReward);
        console.log("stake1 runTime:", runTime);
        console.log("protocol supply in compound:", compoundV3.collateralBalanceOf(address(defiDolly), address(wstETH)));
        console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));
        (uint256 length, uint256 stakedETH, uint256 stakedstETH, uint256 stakedwstETH, uint256 supply, uint256 borrow, uint256 temp, bool isUnstaked) = defiDolly.getStakeOrder(stake1, 0);
        console.log("stake1 stake order length:", length);
        console.log("stake1 stake ETH amount:", stakedETH);
        console.log("stake1 stake stETH amount:", stakedstETH);
        console.log("stake1 stake wstETH amount:", stakedwstETH);
        console.log("stake1 supply amount:", supply);
        console.log("stake1 borrow amount:", borrow);
        console.log("stake1 stakeTime:", temp);
        console.log("stake1 isUnstaked:", isUnstaked);
        console.log("protocol supply in compound:", compoundV3.collateralBalanceOf(address(defiDolly), address(wstETH)));
        console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));

        vm.stopPrank();
    }

    function testRefferal() external {
        vm.startPrank(stake1);
        defiDolly.stake{ value: 1 ether }(address(stake2));
        (address account, uint256 time, uint256 unstakeReward ) = defiDolly.getReferee(stake2, stake1);
        console.log("stake2 account: ", account);
        console.log("stake2 time: ", time);
        console.log("stake2 unstakeReward: ", unstakeReward);
        vm.stopPrank();

        vm.startPrank(stake2);
        defiDolly.stake{ value: 1 ether }(address(stake1));
        (account, time, unstakeReward ) = defiDolly.getReferee(stake1, stake2);
        console.log("stake1 account: ", account);
        console.log("stake1 time: ", time);
        console.log("stake1 unstakeReward: ", unstakeReward);
        vm.stopPrank();
    }

    function testClaimRefferalReward() external {
        vm.startPrank(stake1);
        defiDolly.stake{ value: 1 ether }(address(stake2));
        
        // defiDolly.setWstToSt(wstETH.getStETHByWstETH(1 ether) + 94399040735289);
        // vm.roll(block.number + 10000);

        console.log("protocol earn:   ", defiDolly.getProtocolEarn(stake1));
        console.log("getWillClaimRefferalReward : ", defiDolly.getWillClaimRefferalReward(stake2));

        defiDolly.unstake();

        console.log("protocol earn:   ", defiDolly.protocolEarn());
        console.log("Refferal Reward: ", defiDolly.getCanClaimRefferalReward(stake2));
        console.log("getWillClaimRefferalReward : ", defiDolly.getWillClaimRefferalReward(stake2));

        vm.stopPrank();

        vm.startPrank(stake2);
        uint refferalReward = defiDolly.claimRefferalReward();
        console.log("refferalReward: ", refferalReward);
        console.log("balance of weth: ", wETH.balanceOf(stake2));
        vm.stopPrank();
    }

    function testSupplyPosition() external {
        vm.startPrank(stake1);
        defiDolly.stake{ value: 10 ether }(address(stake2));
        vm.stopPrank();

        vm.startPrank(owner);
        (bool sent,) = address(wETH).call{value: 50 ether}("");
        require(sent, "Failed to send Ether");
        wETH.approve(address(defiDolly), 1 ether);
        defiDolly.supplyPosition(1 ether);
        vm.stopPrank();

        vm.startPrank(stake1);
        vm.expectRevert("now is paused");
        defiDolly.stake{ value: 1 ether }(address(0));
        vm.stopPrank();

        vm.startPrank(owner);
        defiDolly.withdrawSupplyPosition();
        vm.stopPrank();

        vm.startPrank(stake1);
        defiDolly.stake{ value: 1 ether }(address(0));
        vm.stopPrank();


    }

    //1000000000000000000
    function testComplex() external {
        vm.prank(stake1);
        address(stETH).call{value: 50 ether}("");
        vm.prank(stake2);
        address(stETH).call{value: 50 ether}("");

        // stake1 stake 2.33 eth and 0.22 stETH
        // test: refferal wether change to owner and wether change address(0)
        vm.startPrank(stake1);
        defiDolly.stake{ value: 1 ether }(address(stake2));
        defiDolly.stake{ value: 1 ether }(address(owner));
        (, , , address refferal, , , ) = defiDolly.accounts(stake1);
        defiDolly.stake{ value: 330000000000000000 }(address(0));
        (, , , refferal, , , ) = defiDolly.accounts(stake2);
        stETH.approve(address(defiDolly), 220000000000000000);
        defiDolly.stakeSTETH(220000000000000000, address(stake2));
        vm.stopPrank();

        // stake2 stake 1.08 eth
        // test: check refferal wether change from address(0) to other
        vm.startPrank(stake2);
        defiDolly.stake{ value: 500000000000000000 }(address(0));
        defiDolly.stake{ value: 250000000000000000 }(address(stake1));
        (, , , refferal, , , ) = defiDolly.accounts(stake2);
        defiDolly.stake{ value: 330000000000000000 }(address(0));
        vm.stopPrank();

        // a few days ago
        // console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));
        // vm.roll(block.number + 10000);
        // console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));
        // vm.prank(owner);
        // defiDolly.setWstToSt(defiDolly.getStETHByWstETH(1000000000000000000) + 1000000000000000);

        // stake1 unstake
        // test: check refferal wether change from address(0) to other
        vm.prank(stake1);
        uint256 amount = defiDolly.unstake();
        console.log("stake1 unstake amount: ", amount);

        // stake2 stake 1.28 eth and 0.4 stETH
        // test: check refferal wether change from address(0) to other
        vm.startPrank(stake2);
        defiDolly.stake{ value: 200000000000000000 }(address(0));
        stETH.approve(address(defiDolly), 400000000000000000);
        defiDolly.stakeSTETH(400000000000000000, address(0));
        vm.stopPrank();

        // stake1 stake 2 eth and 0.5 stETH
        // test: check refferal wether change from address(0) to other
        vm.startPrank(stake1);
        defiDolly.stake{ value: 2000000000000000000 }(address(owner));
        (, , , refferal, , , ) = defiDolly.accounts(stake1);
        assertNotEq(refferal, owner);
        stETH.approve(address(defiDolly), 500000000000000000);
        defiDolly.stakeSTETH(500000000000000000, address(0));
        vm.stopPrank();

        console.log("********************************************************");
        (uint256 totalStakedETH, uint256 totalStakedstETH, uint256 totalStakedwstETH, address refferal2, uint256 claimedReward, uint256 runTime, ) = defiDolly.accounts(stake1);
        console.log("stake1 total stake ETH amount:", totalStakedETH);
        console.log("stake1 total stake stETH amount:", totalStakedstETH);
        console.log("stake1 total stake wstETH amount:", totalStakedwstETH);
        console.log("stake1 refferal:", refferal2);
        console.log("stake1 claimedReward: ", claimedReward);
        console.log("stake1 runTime:", runTime);
        console.log("********************************************************");
        (totalStakedETH, totalStakedstETH, totalStakedwstETH, refferal, claimedReward, runTime, ) = defiDolly.accounts(stake2);
        console.log("stake2 total stake ETH amount:", totalStakedETH);
        console.log("stake2 total stake stETH amount:", totalStakedstETH);
        console.log("stake2 total stake wstETH amount:", totalStakedwstETH);
        console.log("stake2 refferal:", refferal);
        console.log("stake2 claimedReward: ", claimedReward);
        console.log("stake2 runTime:", runTime);
        console.log("********************************************************");
        console.log("protocol supply in compound:", compoundV3.collateralBalanceOf(address(defiDolly), address(wstETH)));
        console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));

        vm.prank(stake1);
        amount = defiDolly.unstake();
        console.log("stake1 unstake amount: ", amount);

        vm.prank(stake2);
        amount = defiDolly.unstake();
        console.log("stake2 unstake amount: ", amount);

        console.log("protocol supply in compound:", compoundV3.collateralBalanceOf(address(defiDolly), address(wstETH)));
        console.log("protocol borrow in compound:", compoundV3.borrowBalanceOf(address(defiDolly)));
        
    }

    function testStakeOrder() external {

        // stake1 stake 2.33 eth and 0.22 stETH
        // test: refferal wether change to owner and wether change address(0)
        vm.startPrank(stake1);
        defiDolly.stake{ value: 1 ether }(address(stake2));
        vm.stopPrank();

        (uint256 length, uint256 stakedETH, uint256 stakedstETH, uint256 stakedwstETH, uint256 supply, uint256 borrow, uint256 temp, bool isUnstaked) = defiDolly.getStakeOrder(stake2, 0);
        console.log("stake2 stake order length:", length);
        console.log("stake2 stake ETH amount:", stakedETH);
        console.log("stake2 stake stETH amount:", stakedstETH);
        console.log("stake2 stake wstETH amount:", stakedwstETH);
        console.log("stake2 supply amount:", supply);
        console.log("stake2 borrow amount:", borrow);
        console.log("stake2 stakeTime:", temp);
        console.log("stake2 isUnstaked:", isUnstaked);
    }


}


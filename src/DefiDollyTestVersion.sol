// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import { Ownable } from "./Ownable.sol";
import { IFlashLoanRecipient, IBalancerVault } from "./interfaces/IBalancer.sol";
import { STETH, WSTETH } from "./interfaces/ILido.sol";
import { ICompoundV3, CometStructs } from "./interfaces/ICompoundV3.sol";
import { IWERC20 } from "./interfaces/IWERC20.sol";
import { IUniswapV3FlashCallback } from "v3-core/interfaces/callback/IUniswapV3FlashCallback.sol";
import { IUniswapV3SwapCallback } from "v3-core/interfaces/callback/IUniswapV3SwapCallback.sol";
import { IUniswapV3Pool } from 'v3-core/interfaces/IUniswapV3Pool.sol';
import { IUniswapV3Factory } from 'v3-core/interfaces/IUniswapV3Factory.sol';
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

import "../lib/forge-std/src/Test.sol";

contract DefiDollyTestVersion is Ownable, IUniswapV3SwapCallback{
    IWERC20 public wETH;
    address public balancerVault;
    STETH public stETH;
    WSTETH public wstETH;
    ICompoundV3 public compoundV3;
    uint16 public maxLeverage;
    uint16 public protocolFee;
    uint16 public refferalFee;
    IUniswapV3Factory private _uniswapV3Factory;
    uint160 private _minSqrtRatio;
    uint160 private _maxSqrtRatio;

    struct Referee {
        address account;
        uint256 time;
        uint256 unstakeReward;
    }

    struct StakeOrder {
        uint256 stakedETH;
        uint256 stakedstETH;
        uint256 stakedwstETH;
        uint256 supply;
        uint256 borrow;
        uint32 leverage;
        uint256 stakeTime;
        bool isUnstaked;
    }

    struct Account {
        uint256 totalStakedETH;
        uint256 totalStakedstETH;
        uint256 totalStakedwstETH;
        StakeOrder [] stakeOrders;
        address refferal;
        Referee [] referee;
        uint256 runTime;
        bool lock;
    }

    struct FlashLoanCallBack {
        address account;
        uint32 index;
    }

    uint256 public totalBorrowETH = 0;
    uint256 public totalstakeETH = 0;
    mapping(address => Account) public accounts;

    event Stake(address account, uint8 coins, uint256 amount, uint256 stakeTime, uint256 totalstakedAmount);
    event Unstake(address account, uint256 unstakedAmount, uint256 returnAmount, uint256 unstakeTime);

    modifier lock() {
        accounts[msg.sender].lock = true;
        _;
    }

    modifier unlock() {
        _;
        accounts[msg.sender].lock = false;
    }

    modifier checkIsLock() {
        require(!accounts[msg.sender].lock, "you are doing something else");
        _;
    }

    modifier checkIsBalancerVault() {
        require(msg.sender == balancerVault);
        _;
    }

    modifier checkIsUniswap() {
        require(msg.sender == _uniswapV3Factory.getPool(address(wstETH), address(wETH), 100));
        _;
    }

    modifier checkReferral(address _referral) {
        if(_referral != address(0x0)){
            require(_referral != msg.sender, "The referral cannot be yourself");
            _addAccount(_referral, address(0x0));
        }
        _;
    }

    receive() external payable {
    }

    function initialize(bool isMain) external onlyOwner() {
        if(isMain){
            wETH = IWERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
            balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
            stETH = STETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
            wstETH = WSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
            compoundV3 = ICompoundV3(0xA17581A9E3356d9A858b789D68B4d866e593aE94);
            _uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        }else{
            wETH = IWERC20(0x42a71137C09AE83D8d05974960fd607d40033499);
            balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
            stETH = STETH(0x2DD6530F136D2B56330792D46aF959D9EA62E276);
            wstETH = WSTETH(0x4942BBAf745f235e525BAff49D31450810EDed5b);
            compoundV3 = ICompoundV3(0x9A539EEc489AAA03D588212a164d0abdB5F08F5F);
            _uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        }
        
        _minSqrtRatio = 4295128739;
        _maxSqrtRatio = 1461446703485210103287273052203988822378723970342;
        maxLeverage = 90;
        protocolFee = 15;
        refferalFee = 5;
    }

    function _flashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) private {
        IBalancerVault(balancerVault).flashLoan(
            IFlashLoanRecipient(address(this)),
            tokens,
            amounts,
            userData
        );
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes calldata userData
    ) external checkIsBalancerVault() {
        IERC20 token = tokens[0];
        uint256 amount = amounts[0];
        uint256 feeAmount = feeAmounts[0];
        require(feeAmount == 0, "balancer now need fee");
        require(token.balanceOf(address(this)) >= amount);
        FlashLoanCallBack memory callbackData = abi.decode(userData, (FlashLoanCallBack));
        StakeOrder storage order = accounts[callbackData.account].stakeOrders[uint256(callbackData.index)];
        wETH.withdraw(amount);
        (bool sent, ) = address(wstETH).call{value: amount}("");
        require(sent, "Failed to send Ether");
        uint totalSupply = amount * (order.leverage + 10) / order.leverage;
        totalSupply = wstETH.getWstETHByStETH(totalSupply) - 1;
        wstETH.approve(address(compoundV3), totalSupply);
        compoundV3.supply(address(wstETH), totalSupply);
        compoundV3.withdraw(address(wETH), amount);
        order.supply = totalSupply;
        order.borrow = amount;
        totalBorrowETH += amount;

        token.transfer(balancerVault, amount);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) checkIsUniswap() external override {
        FlashLoanCallBack memory callbackData = abi.decode(data, (FlashLoanCallBack));
        Account storage account = accounts[callbackData.account];
        uint256 wethAmount = amount1Delta >= 0 ? uint256(amount1Delta) : uint256(-amount1Delta);
        uint256 repay = 0;
        uint256 withdraw = 0;
        for(uint i = 0; i < account.stakeOrders.length; i++){
            if(!account.stakeOrders[i].isUnstaked) {
                repay += account.stakeOrders[i].borrow;
                withdraw += account.stakeOrders[i].supply;
                account.stakeOrders[i].isUnstaked = true;
            }
        }
        uint256 interest = _getCompoundInterest(callbackData.account);
        totalBorrowETH -= repay;
        require(wethAmount > repay + interest, "uniswap get weth not enough");
        wETH.approve(address(compoundV3), repay + interest);
        compoundV3.supply(address(wETH), repay + interest);
        compoundV3.withdraw(address(wstETH), withdraw);
        require(uint256(amount0Delta) == withdraw, "amount0Delta != withdraw");
        wstETH.transfer(msg.sender, uint(amount0Delta));

        wethAmount = wethAmount - repay - interest - _getProtocolEarn(callbackData.account);

        account.totalStakedETH = 0;
        account.totalStakedstETH = 0;
        account.totalStakedwstETH = 0;
        
        wETH.transfer(callbackData.account, wethAmount);
        totalstakeETH -= ( account.totalStakedETH + account.totalStakedstETH);
    }

    function _getBorrowableAmountByWstETH(uint256 amount) internal view returns (int) {
        uint8 numAssets = compoundV3.numAssets();
        uint16 assetsIn = 2;

        int liquidity = 0;
        for (uint8 i = 0; i < numAssets; i++) {
        if (_isInAsset(assetsIn, i)) {
            CometStructs.AssetInfo memory asset = compoundV3.getAssetInfo(i);
            uint newAmount = uint(amount) * _getCompoundPrice(asset.priceFeed) / 1e8;
            liquidity += int(
            newAmount * asset.borrowCollateralFactor / 1e18
            );
        }
        }

        return liquidity;
    }

    function _getBorrowableAmount(address account) internal view returns (int) {
        uint8 numAssets = compoundV3.numAssets();
        uint16 assetsIn = compoundV3.userBasic(account).assetsIn;
        uint64 si = compoundV3.totalsBasic().baseSupplyIndex;
        uint64 bi = compoundV3.totalsBasic().baseBorrowIndex;
        address baseTokenPriceFeed = compoundV3.baseTokenPriceFeed();

        int liquidity = int(
        _presentValue(compoundV3.userBasic(account).principal, si, bi) *
        int256(_getCompoundPrice(baseTokenPriceFeed)) /
        int256(1e8)
        );
        for (uint8 i = 0; i < numAssets; i++) {
        if (_isInAsset(assetsIn, i)) {
            CometStructs.AssetInfo memory asset = compoundV3.getAssetInfo(i);
            uint newAmount = uint(compoundV3.userCollateral(account, asset.asset).balance) * _getCompoundPrice(asset.priceFeed) / 1e8;
            liquidity += int(
            newAmount * asset.borrowCollateralFactor / 1e18
            );
        }
        }

        return liquidity;
    }

    function _getCompoundPrice(address singleAssetPriceFeed) internal view returns (uint) {
        return compoundV3.getPrice(singleAssetPriceFeed);
    }

    function _isInAsset(uint16 assetsIn, uint8 assetOffset) internal pure returns (bool) {
        return (assetsIn & (uint16(1) << assetOffset) != 0);
    }

    function _presentValue(
        int104 principalValue_,
        uint64 baseSupplyIndex_,
        uint64 baseBorrowIndex_
    ) internal view returns (int104) {
        if (principalValue_ >= 0) {
        return int104(uint104(principalValue_) * baseSupplyIndex_ / uint64(compoundV3.baseIndexScale()));
        } else {
        return -int104(uint104(principalValue_) * baseBorrowIndex_ / uint64(compoundV3.baseIndexScale()));
        }
    }

    function getStakeOrder(address _user, uint256 _index) external view returns(uint256, uint256, uint256, uint256, uint256, uint32, uint256) {
        require(_index < accounts[_user].stakeOrders.length, "out of index");
        StakeOrder memory order = accounts[_user].stakeOrders[_index];
        return ( order.stakedETH, order.stakedstETH, order.stakedwstETH, order.supply, order.borrow, order.leverage, order.stakeTime );
    }

    function getReferee(address _user, uint256 _index) external view returns(address, uint256, uint256) {
        require(_index < accounts[_user].referee.length, "out of index");
        Referee memory referee = accounts[_user].referee[_index];
        return ( referee.account, referee.time, referee.unstakeReward );
    }

    function stake(address _referral) external payable checkIsLock lock unlock checkReferral(_referral) returns(uint256 stakeAmountETH) {
        (bool sent, ) = address(wstETH).call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        _stake(0, msg.value, _referral);
        return accounts[msg.sender].totalStakedETH;
    }

    function stakeSTETH(uint _amount, address _referral) external payable checkIsLock lock unlock checkReferral(_referral) returns(uint256 stakeAmountETH) {
        stETH.transferFrom(msg.sender, address(this), _amount);
        stETH.approve(address(wstETH), _amount * 2);
        wstETH.wrap(_amount);
        _stake(1, _amount, _referral);
        return accounts[msg.sender].totalStakedETH;
    }

    function _stake(uint8 coins, uint _amount, address _referral) internal {
        _addAccount(msg.sender, _referral);
        totalstakeETH += _amount;
        uint32 _leverage = maxLeverage;
        for(uint i = 0; i < 100; i++){
            uint256 tempTokenAmount = _amount * ( _leverage + 10 ) / 10;
            if(uint256(_getBorrowableAmountByWstETH(wstETH.getWstETHByStETH(tempTokenAmount))) > _amount * _leverage / 10){
                break;
            }
            _leverage -= 1;
        }
        uint256 tokenAmount = _amount * _leverage / 10;
        uint32 index = _addStakeOrders(coins, _amount, _leverage);
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = wETH;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = tokenAmount;

        FlashLoanCallBack memory callbackData = FlashLoanCallBack({
            account: msg.sender,
            index: index
        });

        _flashLoan(tokens, amounts, abi.encode(callbackData));
        Account memory account = accounts[msg.sender];
        emit Stake(msg.sender, coins, _amount, block.timestamp, account.totalStakedETH + account.totalStakedstETH);
    }

    function _addAccount(address user, address _referral) private {
        Account storage account = accounts[user];
        if(account.runTime <= 0){
            account.totalStakedETH = 0;
            account.totalStakedstETH = 0;
            account.totalStakedwstETH = 0;
            account.refferal = _referral;
            account.runTime = block.timestamp;
            if(_referral != address(0x0)){
                accounts[_referral].referee.push(Referee({
                    account: user,
                    time: block.timestamp,
                    unstakeReward: 0
                }));
            }
        }else if(account.refferal == address(0x0)){
            account.refferal = _referral;
            if(_referral != address(0x0)){
                accounts[_referral].referee.push(Referee({
                    account: user,
                    time: block.timestamp,
                    unstakeReward: 0
                }));
            }
        }
    }

    function _addStakeOrders(uint8 coins, uint _amount, uint32 _leverage) private returns(uint32 index) {
        Account storage account = accounts[msg.sender];
        account.totalStakedETH += coins == 0 ? _amount : 0;
        account.totalStakedstETH += coins == 1 ? _amount : 0;
        account.totalStakedwstETH += wstETH.getWstETHByStETH(_amount);
        accounts[msg.sender].stakeOrders.push(StakeOrder({
            stakedETH: coins == 0 ? _amount : 0,
            stakedstETH: coins == 1 ? _amount : 0,
            stakedwstETH: wstETH.getWstETHByStETH(_amount),
            supply: 0,
            borrow: 0,
            leverage: _leverage,
            stakeTime: block.timestamp,
            isUnstaked: false
        }));
        index = uint32(account.stakeOrders.length - 1);
    }

    function _getCompoundInterest(address _account) internal view returns(uint256) {
        Account memory account = accounts[_account];
        uint256 accountInterest = ( compoundV3.borrowBalanceOf(address(this)) - totalBorrowETH ) * account.totalStakedETH / totalstakeETH;
        return accountInterest;
    }

    function _getTotalEarn(address _account) internal view returns(int256 earn) {
        Account memory account = accounts[_account];
        uint256 totalSupply = 0;
        uint256 totalBorrow = 0;
        for(uint i = 0; i < account.stakeOrders.length; i++){
            if(!account.stakeOrders[i].isUnstaked) {
                totalSupply += account.stakeOrders[i].supply;
                totalBorrow += account.stakeOrders[i].borrow;
            }
        }
        earn = int256(wstETH.getStETHByWstETH(totalSupply)) - int256(totalBorrow) - int256(_getCompoundInterest(_account)) - int256(account.totalStakedETH) - int256(account.totalStakedstETH);
    }

    function _getProtocolEarn(address _account) internal view returns(uint256) {
        uint256 earn = _getTotalEarn(_account) >= 0 ? uint256(_getTotalEarn(_account)) : 0;
        return earn * protocolFee / 100;
    }

    function _getAccountEarn(address _account) internal view returns(uint256) {
        uint256 earn = _getTotalEarn(_account) >= 0 ? uint256(_getTotalEarn(_account)) : 0;
        return earn * ( 100 - protocolFee ) / 100;
    }

    function getAccountStakedAmount(address _account) external view returns(uint256) {
        Account memory account = accounts[_account];
        if( ( account.totalStakedETH + account.totalStakedstETH ) >= wstETH.getStETHByWstETH(account.totalStakedwstETH)) {
            return account.totalStakedETH + account.totalStakedstETH;
        }
        return account.totalStakedETH + account.totalStakedstETH + _getAccountEarn(_account);
    }

    function unstake() external payable checkIsLock lock unlock returns(uint256 unstakeAmountETH) {
        Account storage account = accounts[msg.sender];
        uint256 amount = 0;
        uint256 repay = 0;
        for(uint i = 0; i < account.stakeOrders.length; i++){
            if(!account.stakeOrders[i].isUnstaked) {
                repay += account.stakeOrders[i].borrow;
                amount += account.stakeOrders[i].supply;
            }
        }
        uint256 interest = _getCompoundInterest(msg.sender);
        uint256 protocolEarn = _getProtocolEarn(msg.sender);
        IUniswapV3Pool pool = IUniswapV3Pool(_uniswapV3Factory.getPool(address(wstETH), address(wETH), 100));
        bool zeroForOne = true;
        uint160 sqrtPriceLimitX96 = zeroForOne
            ? _minSqrtRatio + 1
            : _maxSqrtRatio - 1;


        FlashLoanCallBack memory callbackData = FlashLoanCallBack({
            account: msg.sender,
            index: 0
        });

        (, int256 amount1) = pool.swap(address(this), zeroForOne, int256(amount), sqrtPriceLimitX96, abi.encode(callbackData));
        unstakeAmountETH = amount1 >= 0 ? uint256(amount1) : uint256(-amount1);
        unstakeAmountETH = unstakeAmountETH - repay - interest - protocolEarn;

        emit Unstake(msg.sender, amount, unstakeAmountETH, block.timestamp);
    }

}

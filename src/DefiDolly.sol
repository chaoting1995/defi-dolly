// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import { Ownable } from "./Ownable.sol";
import { Pausable } from "./Pausable.sol";
import { IFlashLoanRecipient, IBalancerVault } from "./interfaces/IBalancer.sol";
import { STETH, WSTETH } from "./interfaces/ILido.sol";
import { ICompoundV3, CometStructs } from "./interfaces/ICompoundV3.sol";
import { IWERC20 } from "./interfaces/IWERC20.sol";
import { Error } from "./interfaces/Error.sol";
import { IUniswapV3SwapCallback } from "v3-core/interfaces/callback/IUniswapV3SwapCallback.sol";
import { IUniswapV3Pool } from 'v3-core/interfaces/IUniswapV3Pool.sol';
import { IUniswapV3Factory } from 'v3-core/interfaces/IUniswapV3Factory.sol';
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DefiDolly is Ownable, Pausable, IUniswapV3SwapCallback, Error{
    IWERC20 private _wETH;
    address private _balancerVault;
    STETH private _stETH;
    WSTETH private _wstETH;
    ICompoundV3 private _compoundV3;
    uint16 private _protocolFee;
    uint16 private _refferalFee;
    IUniswapV3Factory private _uniswapV3Factory;
    uint160 private _minSqrtRatio;
    uint160 private _maxSqrtRatio;

    struct Referee {
        uint256 time;
        uint256 unstakeReward;
    }

    struct StakeOrder {
        uint256 stakedETH;
        uint256 stakedstETH;
        uint256 stakedwstETH;
        uint256 supply;
        uint256 borrow;
        uint256 stakeTime;
        bool isUnstaked;
    }

    struct Account {
        uint256 totalStakedETH;
        uint256 totalStakedstETH;
        uint256 totalStakedwstETH;
        StakeOrder [] stakeOrders;
        address refferal;
        address [] refereeList;
        mapping( address => Referee ) referee;
        uint256 claimedReward;
        uint256 runTime;
        bool lock;
    }

    struct FlashLoanCallBack {
        address account;
        uint32 index;
    }

    uint256 public totalBorrowETH = 0;
    uint256 public totalStakeETH = 0;
    uint256 public protocolEarn = 0;
    uint256 public supplyPositionAmount = 0;
    mapping(address => Account) public accounts;
    event Stake(address account, uint8 coins, uint256 amount, uint256 stakeTime, uint256 totalstakedAmount);
    event Unstake(address account, uint256 unstakedAmount, uint256 returnAmount, uint256 unstakeTime);
    event ClaimRefferalReward(address account, uint256 claimAmount, uint256 claimTime);
    event SupplyPosition(uint256 amount);
    event WithdrawSupplyPosition(uint256 amount);
    event WithdrawProtocolEarn(address account, uint256 amount);

    function _lock() private {
        accounts[msg.sender].lock = true;
    }

    modifier unlock() {
        _;
        accounts[msg.sender].lock = false;
    }

    function _checkIsLock() private view {
        if(accounts[msg.sender].lock){
            revert YouAreDoingSomethingElse();
        }
    }

    modifier checkIsBalancerVault() {
        if(msg.sender != _balancerVault){
            revert NotBalancerVaultAddress();
        }
        _;
    }

    modifier checkIsUniswap() {
        if(msg.sender != _uniswapV3Factory.getPool(address(_wstETH), address(_wETH), 100)){
            revert NotUniswapPoolAddress();
        }
        _;
    }

    modifier checkReferral(address _referral) {
        if(_referral != address(0x0)){
            if(_referral == msg.sender){
                revert TheReferralCanNotBeYourself();
            }
            _addAccount(_referral, address(0x0));
        }
        _;
    }

    receive() external payable {
    }

    function initialize() external onlyOwner() {
        _wETH = IWERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        _balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
        _stETH = STETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        _wstETH = WSTETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        _compoundV3 = ICompoundV3(0xA17581A9E3356d9A858b789D68B4d866e593aE94);
        _uniswapV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        _minSqrtRatio = 4295128739;
        _maxSqrtRatio = 1461446703485210103287273052203988822378723970342;
        _protocolFee = 15;
        _refferalFee = 5;
    }

    function _flashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) private {
        IBalancerVault(_balancerVault).flashLoan(
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
    ) external payable checkIsBalancerVault() {
        IERC20 token = tokens[0];
        uint256 amount = amounts[0];
        uint256 feeAmount = feeAmounts[0];
        if(feeAmount != 0){
            revert BalancerNowNeedFee();
        }
        if(token.balanceOf(address(this)) < amount) {
            revert CheckGetTokenFromBalancer();
        }
        FlashLoanCallBack memory callbackData = abi.decode(userData, (FlashLoanCallBack));
        StakeOrder storage order = accounts[callbackData.account].stakeOrders[uint256(callbackData.index)];
        _wETH.withdraw(amount);
        (bool sent, ) = address(_wstETH).call{value: amount}("");
        if(!sent) {
            revert FailedToSendEther();
        }
        uint totalSupply = amount + order.stakedstETH + order.stakedETH;
        totalSupply = _wstETH.getWstETHByStETH(totalSupply) - 1;
        _wstETH.approve(address(_compoundV3), totalSupply);
        _compoundV3.supply(address(_wstETH), totalSupply);
        _compoundV3.withdraw(address(_wETH), amount);
        order.supply = totalSupply;
        order.borrow = amount;
        totalBorrowETH += amount;

        token.transfer(_balancerVault, amount);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) checkIsUniswap() external override {
        FlashLoanCallBack memory callbackData = abi.decode(data, (FlashLoanCallBack));
        Account storage account = accounts[callbackData.account];
        uint256 wethAmount = amount1Delta >= 0 ? uint256(amount1Delta) : uint256(-amount1Delta);
        uint256 _protocolEarn = getProtocolEarn(callbackData.account);
        uint256 refferalReward = _getRefferalReward(callbackData.account);
        uint256 repay = 0;
        uint256 withdraw = 0;
        for(uint i = 0; i < account.stakeOrders.length; i++){
            if(!account.stakeOrders[i].isUnstaked) {
                repay += account.stakeOrders[i].borrow;
                withdraw += account.stakeOrders[i].supply;
                account.stakeOrders[i].isUnstaked = true;
            }
        }
        uint256 interest = getCompoundInterest(callbackData.account);
        totalBorrowETH -= repay;
        _wETH.approve(address(_compoundV3), repay + interest);
        _compoundV3.supply(address(_wETH), repay + interest);
        _compoundV3.withdraw(address(_wstETH), withdraw);
        _wstETH.transfer(msg.sender, uint(amount0Delta));
        if(account.refferal != address(0x0)){
            accounts[account.refferal].referee[callbackData.account].unstakeReward += refferalReward;
        }
        protocolEarn += _protocolEarn;
        if(wethAmount < repay + interest + _protocolEarn){
            revert UniswapGetWethNotEnough();
        }
        wethAmount = wethAmount - repay - interest - _protocolEarn;
        totalStakeETH -= ( account.totalStakedETH + account.totalStakedstETH);
        account.totalStakedETH = 0;
        account.totalStakedstETH = 0;
        account.totalStakedwstETH = 0;
        
        _wETH.transfer(callbackData.account, wethAmount);
    }

    function _getBorrowableAmountByWstETH(uint256 amount) private view returns (int liquidity) {
        uint8 numAssets = _compoundV3.numAssets();
        uint16 assetsIn = 2;

        for (uint8 i = 0; i < numAssets; i++) {
            if (_isInAsset(assetsIn, i)) {
                CometStructs.AssetInfo memory asset = _compoundV3.getAssetInfo(i);
                uint newAmount = uint(amount) * _getCompoundPrice(asset.priceFeed) / 1e8;
                liquidity += int(
                newAmount * asset.borrowCollateralFactor / 1e18
                );
            }
        }

        return liquidity;
    }

    function _getCompoundPrice(address singleAssetPriceFeed) private view returns (uint) {
        return _compoundV3.getPrice(singleAssetPriceFeed);
    }

    function _isInAsset(uint16 assetsIn, uint8 assetOffset) private pure returns (bool) {
        return (assetsIn & (uint16(1) << assetOffset) != 0);
    }

    function getStakeOrder(address _user, uint256 _index) external view returns(uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool) {
        if(accounts[_user].stakeOrders.length == 0){
            return ( 0, 0, 0, 0, 0, 0, 0, false );
        }
        if(_index >= accounts[_user].stakeOrders.length){
            revert OutOfIndex();
        }
        StakeOrder memory order = accounts[_user].stakeOrders[_index];
        return ( accounts[_user].stakeOrders.length, order.stakedETH, order.stakedstETH, order.stakedwstETH, order.supply, order.borrow, order.stakeTime, order.isUnstaked );
    }

    function getRefereeList(address _user) external view returns(uint256 , address[] memory) {
        return (accounts[_user].refereeList.length, accounts[_user].refereeList);
    }

    function getReferee(address _user, address _referee) external view returns(address, uint256, uint256) {
        Referee memory referee = accounts[_user].referee[_referee];
        return ( _user, referee.time, referee.unstakeReward );
    }

    function stake(address _referral) external payable checkPaused unlock checkReferral(_referral) returns(uint256 stakeAmountETH) {
        _checkIsLock();
        _lock();
        (bool sent, ) = address(_wstETH).call{value: msg.value}("");
        if(!sent) {
            revert FailedToSendEther();
        }
        _stake(0, msg.value, _referral);
        return accounts[msg.sender].totalStakedETH;
    }

    function stakeSTETH(uint _amount, address _referral) external payable checkPaused unlock checkReferral(_referral) returns(uint256 stakeAmountETH) {
        _checkIsLock();
        _lock();
        _stETH.transferFrom(msg.sender, address(this), _amount);
        _stETH.approve(address(_wstETH), _amount);
        _wstETH.wrap(_amount);
        _stake(1, _amount, _referral);
        return accounts[msg.sender].totalStakedETH;
    }

    function _stake(uint8 coins, uint _amount, address _referral) private {
        _addAccount(msg.sender, _referral);
        totalStakeETH += _amount;

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = _wETH;
        uint256[] memory amounts = new uint256[](1);

        uint32 _leverage = 90;
        for(uint i = 0; i < 10; i++){
            uint256 tempTokenAmount = _amount * ( _leverage + 10 ) / 10;
            if(uint256(_getBorrowableAmountByWstETH(_wstETH.getWstETHByStETH(tempTokenAmount))) > _amount * _leverage / 10){
                break;
            }
            _leverage -= 1;
        }
        amounts[0] = _amount * _leverage / 10;

        uint32 index = _addStakeOrders(coins, _amount, amounts[0]);
        
        FlashLoanCallBack memory callbackData = FlashLoanCallBack({
            account: msg.sender,
            index: index
        });

        _flashLoan(tokens, amounts, abi.encode(callbackData));
        Account storage account = accounts[msg.sender];
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
            _addReferee(user, _referral);
        }else if(account.refferal == address(0x0) && account.stakeOrders.length == 0){
            account.refferal = _referral;
            _addReferee(user, _referral);
        }
    }

    function _addReferee(address user, address _referral) private {
        if(_referral != address(0x0)){
            accounts[_referral].refereeList.push(user);
            accounts[_referral].referee[user] = Referee({
                time: block.timestamp,
                unstakeReward: 0
            });
        }
    }

    function _addStakeOrders(uint8 coins, uint _amount, uint _borrow) private returns(uint32 index) {
        Account storage account = accounts[msg.sender];
        account.totalStakedETH += coins == 0 ? _amount : 0;
        account.totalStakedstETH += coins == 1 ? _amount : 0;
        account.totalStakedwstETH += _wstETH.getWstETHByStETH(_amount);
        accounts[msg.sender].stakeOrders.push(StakeOrder({
            stakedETH: coins == 0 ? _amount : 0,
            stakedstETH: coins == 1 ? _amount : 0,
            stakedwstETH: _wstETH.getWstETHByStETH(_amount),
            supply: _borrow,
            borrow: 0,
            stakeTime: block.timestamp,
            isUnstaked: false
        }));
        index = uint32(account.stakeOrders.length - 1);
    }

    function getCompoundInterest(address _account) public view returns(uint256) {
        if(totalStakeETH == 0){
            return 0;
        }
        Account storage account = accounts[_account];
        uint256 accountTotalSupply = 0;
        for(uint i = 0; i < account.stakeOrders.length; i++){
            if(!account.stakeOrders[i].isUnstaked){
                accountTotalSupply += account.stakeOrders[i].supply;
            }
        }
        uint256 accountInterest = ( _compoundV3.borrowBalanceOf(address(this)) - totalBorrowETH ) * accountTotalSupply / _compoundV3.collateralBalanceOf(address(this), address(_wstETH));
        return accountInterest;
    }

    function getTotalEarn(address _account) public view returns(int256 earn) {
        Account storage account = accounts[_account];
        if(account.totalStakedwstETH == 0){
            return 0;
        }
        uint256 totalSupply = 0;
        uint256 totalBorrow = 0;
        for(uint i = 0; i < account.stakeOrders.length; i++){
            if(!account.stakeOrders[i].isUnstaked) {
                totalSupply += account.stakeOrders[i].supply;
                totalBorrow += account.stakeOrders[i].borrow;
            }
        }
        earn = int256(_wstETH.getStETHByWstETH(totalSupply)) - int256(totalBorrow) - int256(getCompoundInterest(_account)) - int256(account.totalStakedETH) - int256(account.totalStakedstETH);
    }

    function getProtocolEarn(address _account) public view returns(uint256) {
        uint256 earn = getTotalEarn(_account) >= 0 ? uint256(getTotalEarn(_account)) : 0;
        if(accounts[_account].refferal != address(0x0)){
            return earn * ( _protocolFee - _refferalFee ) / 100;
        }
        return earn * _protocolFee / 100;
    }

    function _getRefferalReward(address _account) private view returns(uint256) {
        uint256 earn = getTotalEarn(_account) >= 0 ? uint256(getTotalEarn(_account)) : 0;
        return earn * _refferalFee / 100;
    }

    function getCanClaimRefferalReward(address _account) public view returns(uint256 refferalReward) {
        Account storage account = accounts[_account];
        for(uint i = 0; i < account.refereeList.length; i++){
            refferalReward += account.referee[account.refereeList[i]].unstakeReward;
        }
    }

    function getWillClaimRefferalReward(address _account) public view returns(uint256 refferalReward) {
        Account storage account = accounts[_account];
        for(uint i = 0; i < account.refereeList.length; i++){
            refferalReward += _getRefferalReward(account.refereeList[i]);
        }
    }

    function getAccountEarn(address _account) public view returns(uint256) {
        uint256 earn = getTotalEarn(_account) >= 0 ? uint256(getTotalEarn(_account)) : 0;
        return earn * ( 100 - _protocolFee ) / 100;
    }

    function getAccountStakedAmount(address _account) external view returns(uint256) {
        Account storage account = accounts[_account];
        if( ( account.totalStakedETH + account.totalStakedstETH ) >= _wstETH.getStETHByWstETH(account.totalStakedwstETH)) {
            return account.totalStakedETH + account.totalStakedstETH;
        }
        return account.totalStakedETH + account.totalStakedstETH + getAccountEarn(_account);
    }

    function unstake() external payable checkPaused unlock returns(uint256 unstakeAmountETH) {
        _checkIsLock();
        _lock();
        Account storage account = accounts[msg.sender];
        uint256 amount = 0;
        uint256 repay = 0;
        for(uint i = 0; i < account.stakeOrders.length; i++){
            if(!account.stakeOrders[i].isUnstaked) {
                repay += account.stakeOrders[i].borrow;
                amount += account.stakeOrders[i].supply;
            }
        }
        uint256 _interest = getCompoundInterest(msg.sender);
        uint256 _protocolEarn = getProtocolEarn(msg.sender);
        IUniswapV3Pool pool = IUniswapV3Pool(_uniswapV3Factory.getPool(address(_wstETH), address(_wETH), 100));
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
        unstakeAmountETH = unstakeAmountETH - repay - _interest - _protocolEarn;

        emit Unstake(msg.sender, amount, unstakeAmountETH, block.timestamp);
    }

    function claimRefferalReward() external payable returns(uint256 refferalReward) {
        Account storage account = accounts[msg.sender];
        refferalReward = getCanClaimRefferalReward(msg.sender);
        for(uint i = 0; i < account.refereeList.length; i++){
            account.referee[account.refereeList[i]].unstakeReward = 0;
        }
        account.claimedReward += refferalReward;
        _wETH.transfer(msg.sender, refferalReward);
        emit ClaimRefferalReward(msg.sender, refferalReward, block.timestamp);
    }

    function supplyPosition(uint256 amount) external payable onlyOwner() {
        _pause();
        if(_compoundV3.borrowBalanceOf(address(this)) < amount){
            revert CompoundBorrowLessThenAmount();
        }
        _wETH.transferFrom(msg.sender, address(this), amount);
        _wETH.approve(address(_compoundV3), amount);
        _compoundV3.supply(address(_wETH), amount);
        supplyPositionAmount += amount;
        emit SupplyPosition(amount);
    }

    function withdrawSupplyPosition() external payable onlyOwner() {
        _compoundV3.withdraw(address(_wETH), supplyPositionAmount);
        _wETH.transfer(msg.sender, supplyPositionAmount);
        emit WithdrawSupplyPosition(supplyPositionAmount);
        supplyPositionAmount = 0;
        _unpause();
    }

    function withdrawProtocolEarn() external payable {
        _wETH.transfer(getOwner(), protocolEarn);
        emit WithdrawProtocolEarn(msg.sender, protocolEarn);
        protocolEarn = 0;
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Error {
    error YouAreDoingSomethingElse();
    error NotBalancerVaultAddress();
    error NotUniswapPoolAddress();
    error BalancerNowNeedFee();
    error CheckGetTokenFromBalancer();
    error FailedToSendEther();
    error TheReferralCanNotBeYourself();
    error UniswapGetWethNotEnough();
    error OutOfIndex();
    error CompoundBorrowLessThenAmount();
}
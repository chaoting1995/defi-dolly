// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//0x828b154032950C8ff7CF8085D841723Db2696056
interface ICurve {
    function get_dy(int128 i,int128 j,uint256 dx) external view returns (uint128);
    function exchange(int128 i, int128 j, uint256 _dx, uint256 _min_dy, address _receiver) external returns (uint256);
}


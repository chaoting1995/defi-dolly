// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

contract Ownable {

    struct AddressSlot {
        address value;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {}

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function getOwner() public view returns(address) {
        return _getAddressSlot(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103).value;
    }

    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    function _checkOwner() internal view virtual {
        require(_getAddressSlot(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103).value == msg.sender, "Ownable: caller is not the owner");
    }
}
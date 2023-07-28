// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

contract Pausable {

    bool private _paused;

    event Pause(address);
    event Unpause(address);

    constructor() {
        _paused = false;
    }

    modifier checkPaused() {
        require(!_paused, "now is paused");
        _;
    }

    function getPaused() public view returns(bool) {
        return _paused;
    }

    function _pause() internal {
        require(!_paused);
        _paused = true;
        emit Pause(msg.sender);
    }

    function _unpause() internal {
        require(_paused);
        _paused = false;
        emit Unpause(msg.sender);
    }
}
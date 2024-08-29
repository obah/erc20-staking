// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenM is ERC20("TokenM", "TKM"){
    address public immutable OWNER;

    constructor(){
        OWNER = msg.sender;
        _mint(msg.sender, 10000);
    }

    function decimals() public pure override returns(uint8) {
        return 2;
    }
    
    function mint() external{
        require(msg.sender == OWNER, "Unauthorized caller!");
        _mint(msg.sender, 10000);
    }
}
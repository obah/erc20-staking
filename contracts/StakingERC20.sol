// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IStake, StakeErrors, StakeEvents} from "./IStake.sol";
import "./Stake.sol";

contract Erc20Staking is ReentrancyGuard, StakeErrors, StakeEvents, Stake {
    address immutable TOKENADDRESS;
    // 0xBD4F3F28d18AD0756219D6ba70bE2b64a090c4BE

    constructor(address _tokenAddress) {
        TOKENADDRESS = _tokenAddress;
    }

    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    function depositTokens(uint256 _amount, uint256 _duration) external nonReentrant {
        if(msg.sender == address(0)) {
            revert AddressZero();
        }

        if(_amount <= 0) {
            revert InvalidDeposit();
        }

        uint256 _userTokenBalance = IERC20(TOKENADDRESS).balanceOf(msg.sender);

        if(_userTokenBalance < _amount) {
            revert InsufficientFunds();
        }

        IERC20(TOKENADDRESS).approve(address(this), _amount);
        IERC20(TOKENADDRESS).transferFrom(msg.sender, address(this), _amount);

        balances[msg.sender] = balances[msg.sender] + _amount;

        StakeRecord storage _stake = userStakes[msg.sender][counter];

        uint256 _durationInSecs = _duration / 1 days; 

        _stake.amount = _amount;
        _stake.depositedAmount = _amount;
        _stake.timeStaked = block.timestamp;
        _stake.maturity = _durationInSecs + block.timestamp;

        counter = counter + 1;

        emit Deposited(msg.sender, _amount, block.timestamp, _duration);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        if(msg.sender == address(0)) {
            revert AddressZero();
        }

        if(balances[msg.sender] <= 0) {
            revert NoActiveStake();
        }

        _payRewards(msg.sender);

        if(_amount < balances[msg.sender]) {
            revert InsufficientFunds();
        }
        
        uint256 _withdrawableFunds = checkWithdrawableFunds(msg.sender);

        if(_withdrawableFunds <= 0) {
            revert ImmatureStake();
        }

        StakeRecord[] storage _userStakes = availableUserStakes[msg.sender];

        uint256 _remainingAmount = _amount;

        for (uint256 i = 0; i < _userStakes.length; i++) {
            StakeRecord storage _stake = _userStakes[i];
            if (_stake.amount > 0) {
                if (_stake.amount >= _remainingAmount) { 
                    _stake.amount = _stake.amount - _remainingAmount;
                    _remainingAmount = 0;

                    if(_stake.amount == 0) {
                        _stake.withdrawn = true;
                    }

                    break;
                } else {
                    _remainingAmount = _remainingAmount - _stake.amount;
                    _stake.amount = 0;
                    _stake.withdrawn = true;
                }
            }
        }

        balances[msg.sender] = balances[msg.sender] - _amount;

        IERC20(TOKENADDRESS).transfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }
}

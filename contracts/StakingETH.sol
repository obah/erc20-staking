// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Stake.sol";


contract EthStaking is ReentrancyGuard, StakeErrors, StakeEvents, Stake {
   
    receive() external payable {}

    function depositETH(uint256 _duration) external payable nonReentrant {
         if(msg.sender == address(0)) {
            revert AddressZero();
        }

        if(msg.value <= 0) {
            revert InvalidDeposit();
        }

        uint256 _balance = _getBalance(msg.sender);

        _balance = _balance + msg.value;

        StakeRecord storage _stake = userStakes[msg.sender][counter];

        uint256 _durationInSecs = _duration / 1 days; 

        _stake.amount = msg.value;
        _stake.depositedAmount = msg.value;
        _stake.timeStaked = block.timestamp;
        _stake.maturity = _durationInSecs + block.timestamp;

        counter = counter + 1;

        emit Deposited(msg.sender, msg.value, block.timestamp, _duration);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        if(msg.sender == address(0)) {
            revert AddressZero();
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

        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to withdraw ETH");

        emit Withdrawn(msg.sender, _amount);
    }
}

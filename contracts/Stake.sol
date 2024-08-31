// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface StakeErrors {
    error AddressZero();
    error InvalidDeposit();
    error NoActiveStake();
    error InsufficientFunds();
    error ImmatureStake();
}

interface StakeEvents {
    event RewardPaid(address indexed owner, uint256 indexed amount);
    event Deposited(address indexed owner, uint256 amount, uint256 indexed time, uint256 indexed duration);
    event Withdrawn(address indexed owner, uint256 indexed amount);
}

abstract contract Stake is StakeErrors, StakeEvents {
    /// @dev keeps track of each address's balance 
    mapping(address => uint256) public balances;

    struct StakeRecord {
        uint256 amount;
        uint256 timeStaked;
        uint256 maturity;
        bool withdrawn;
        uint256 lastRewardTime;
        uint256 reward;
        uint256 depositedAmount;
    }

    uint256 counter;

    /// @dev keeps track of each deposit 
    mapping(address => StakeRecord[]) userStakes;

    mapping(address => StakeRecord[]) availableUserStakes;

    constructor() {}

    function _getBalance(address account) public view  virtual returns(uint256) {
        return balances[account];
    }

    function calculateReward(uint256 amount, uint256 duration) internal view returns(uint256) {
        uint256 timeInSeconds = block.timestamp - duration;
        uint256 timeInYear = timeInSeconds / 52 weeks;  
        uint256 prt = amount * 10 * timeInYear;

        return prt / 100; 
    }

     function getAvailableStakes(address account) internal {
        StakeRecord[] memory _userStakes = userStakes[account];

        StakeRecord[] storage _availableStakes = availableUserStakes[msg.sender];

        for(uint16 i; i< _userStakes.length; i++) {
            if(!_userStakes[i].withdrawn) {
                _availableStakes.push(_userStakes[i]);
            }
        }
    }

    function checkWithdrawableFunds(address account) internal view returns (uint256) {
        StakeRecord[] memory _userStakes = availableUserStakes[account];

        uint256 _withdrawableFunds;

        for(uint16 i; i < _userStakes.length; i++) {
            if(_userStakes[i].maturity >= block.timestamp) {
                _withdrawableFunds = _withdrawableFunds + _userStakes[i].amount;
            }
        }

        return _withdrawableFunds;
    }

    function _payRewards(address account) public {
        if(balances[account] <= 0) {
            revert NoActiveStake();
        }

        StakeRecord[] storage _userStakes = availableUserStakes[account];

        uint256 _totalReward;

        for (uint256 i = 0; i < _userStakes.length; i++) {
            StakeRecord storage _stake = _userStakes[i];

            uint256 _startTime = _stake.lastRewardTime > 0 ? _stake.lastRewardTime : _stake.timeStaked;

            uint256 _duration = block.timestamp - _startTime;

            uint256 _reward = calculateReward(_stake.amount, _duration);

            _totalReward = _totalReward + _reward;
            _stake.reward = _stake.reward + _totalReward;
            _stake.amount = _stake.amount + _totalReward;
            balances[account] = balances[account] + _totalReward;

            _stake.lastRewardTime = block.timestamp;
        }

        emit RewardPaid(account, _totalReward);
    }
}
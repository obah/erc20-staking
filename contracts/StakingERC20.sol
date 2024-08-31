// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Erc20Staking is ReentrancyGuard {
    error AddressZero();
    error InvalidDeposit();
    error NoActiveStake();
    error InsufficientFunds();
    error ImmatureStake();

    address immutable TOKENADDRESS;
    // 0xBD4F3F28d18AD0756219D6ba70bE2b64a090c4BE

    /// @dev keeps track of each address's balance 
    mapping(address => uint256) balances;

    struct Stake {
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
    mapping(address => Stake[]) userStakes;

    mapping(address => Stake[]) availableUserStakes;

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

        IERC20(TOKENADDRESS).transferFrom(msg.sender, address(this), _amount);

        balances[msg.sender] = balances[msg.sender] + _amount;

        Stake storage _stake = userStakes[msg.sender][counter];

        //_secsInDay = 60 * 60 * 24
        uint256 _secsInDay = 86400;

        uint256 _durationInSecs = _duration / _secsInDay; 

        _stake.amount = _amount;
        _stake.depositedAmount = _amount;
        _stake.timeStaked = block.timestamp;
        _stake.maturity = _durationInSecs + block.timestamp;

        counter = counter + 1;
    }

    function calculateReward(uint256 _amount, uint256 _duration) private view returns(uint256) {
        //_yearSeconds = 60 * 60 * 24 * 7 * 52;
        uint256 _yearSeconds = 31449600;

        uint256 _timeInSeconds = block.timestamp - _duration;
        uint256 _timeInYear = _timeInSeconds / _yearSeconds;  
        uint256 _prt = _amount * 10 * _timeInYear;

        return _prt / 100; 
    }

    function getAvailableStakes() private {
        Stake[] memory _userStakes = userStakes[msg.sender];
        Stake[] storage _availableStakes = availableUserStakes[msg.sender];

        for(uint16 i; i< _userStakes.length; i++) {
            if(!_userStakes[i].withdrawn) {
                _availableStakes.push(_userStakes[i]);
            }
        }
    }

    function checkWithdrawableFunds() private view returns (uint256) {
        Stake[] memory _userStakes = availableUserStakes[msg.sender];

        uint256 _withdrawableFunds;

        for(uint16 i; i < _userStakes.length; i++) {
            if(_userStakes[i].maturity >= block.timestamp) {
                _withdrawableFunds = _withdrawableFunds + _userStakes[i].amount;
            }
        }

        return _withdrawableFunds;
    }  

    function payRewards() public {
        if(balances[msg.sender] <= 0) {
            revert NoActiveStake();
        }

        Stake[] storage _userStakes = availableUserStakes[msg.sender];

        uint256 _totalReward;

        for (uint256 i = 0; i < _userStakes.length; i++) {
            Stake storage _stake = _userStakes[i];

            uint256 _startTime = _stake.lastRewardTime > 0 ? _stake.lastRewardTime : _stake.timeStaked;

            uint256 _duration = block.timestamp - _startTime;

            uint256 _reward = calculateReward(_stake.amount, _duration);

            _totalReward = _totalReward + _reward;
            _stake.reward = _stake.reward + _totalReward;
            _stake.amount = _stake.amount + _totalReward;
            balances[msg.sender] = balances[msg.sender] + _totalReward;

            _stake.lastRewardTime = block.timestamp;
        }
    }

    function withdraw(uint256 _amount) external nonReentrant {
        if(msg.sender == address(0)) {
            revert AddressZero();
        }

        if(balances[msg.sender] <= 0) {
            revert NoActiveStake();
        }

        payRewards();

        if(_amount < balances[msg.sender]) {
            revert InsufficientFunds();
        }
        
        uint256 _withdrawableFunds = checkWithdrawableFunds();

        if(_withdrawableFunds <= 0) {
            revert ImmatureStake();
        }

        Stake[] storage _userStakes = availableUserStakes[msg.sender];

        uint256 _remainingAmount = _amount;

        for (uint256 i = 0; i < _userStakes.length; i++) {
            Stake storage _stake = _userStakes[i];
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
    }
}

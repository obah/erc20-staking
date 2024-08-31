// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStake {
    function _getBalance(address account) external view returns(uint256);

    function _payRewards(address account) external;
}

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
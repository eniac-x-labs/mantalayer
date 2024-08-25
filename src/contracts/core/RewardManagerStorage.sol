// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IRewardManager.sol";
import "../interfaces/IDelegationManager.sol";

abstract contract RewardManagerStorage is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, IRewardManager {
    using SafeERC20 for IERC20;

    IDelegationManager public immutable delegationManager;

    IStrategyManager public immutable strategyManager;

    IERC20 public immutable rewardTokenAddress;

    uint256 public stakePercent;

    address public rewardManager;

    address public payFeeManager;

    mapping(address => uint256) public strategyStakeRewards;
    mapping(address => uint256) public operatorRewards;

    constructor(IDelegationManager _delegationManager, IStrategyManager _stragegyManager, IERC20 _rewardTokenAddress, uint256 _stakePercent) {
        delegationManager = _delegationManager;
        strategyManager = _stragegyManager;
        rewardTokenAddress = _rewardTokenAddress;
    }

    uint256[100] private __gap;
}

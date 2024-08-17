// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./RewardManagerStorage.sol";
import "../interfaces/IStrategyBase.sol";
import "../interfaces/IStrategyManager.sol";


contract RewardManager is RewardManagerStorage {
    using SafeERC20 for IERC20;

    modifier onlyRewardManager() {
        require(msg.sender == address(rewardManager), "RewardManager.only reward manager can call this function");
        _;
    }

    modifier onlyPayFeeManager() {
        require(msg.sender == address(payFeeManager), "RewardManager.only pay fee manager can call this function");
        _;
    }

    constructor(
        IDelegationManager _delegationManager,
        IStrategyManager _stragegyManager,
        IERC20 _rewardTokenAddress,
        uint256 _stakePercent
    ) RewardManagerStorage(_delegationManager, _stragegyManager, _rewardTokenAddress, _stakePercent) {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _rewardManager, address _payFeeManager) external initializer {
        payFeeManager = _payFeeManager;
        rewardManager = _rewardManager;
        _transferOwnership(initialOwner);
    }

    function payFee(address strategy, address operator, uint256 baseFee) external onlyPayFeeManager {
        uint256 totalShares = IStrategyBase(strategy).totalShares();

        uint256 operatorShares = delegationManager.operatorShares(operator, IStrategyBase(strategy));

        uint256 operatorTotalFee = baseFee / (operatorShares / totalShares);

        uint256 stakeFee = operatorTotalFee * stakePercent / 100;

        strategyStakeRewards[strategy] = stakeFee;

        uint256 operatorFee = operatorTotalFee - stakeFee;

        operatorRewards[operator] = operatorFee;

        emit OperatorAndStakeReward(
            strategy,
            operator,
            stakeFee,
            operatorFee
        );
    }

    function operatorClaimReward() external returns (bool) {
        uint256 claimAmount = operatorRewards[msg.sender];
        rewardTokenAddress.safeTransferFrom(address(this), msg.sender, claimAmount);
        operatorRewards[msg.sender] = 0;
        emit OperatorClaimReward(
            msg.sender,
            claimAmount
        );
        return true;
    }

    function stakeHolderClaimReward(address strategy) external returns (bool) {
        uint256 stakeHoldersShare = strategyManager.stakerStrategyShares(msg.sender, IStrategyBase(strategy));
        uint256 strategyShares = IStrategyBase(strategy).totalShares();
        if (stakeHoldersShare == 0 ||strategyShares == 0) {
            return false;
        }
        uint256 stakeHolderAmount = strategyStakeRewards[strategy] * (stakeHoldersShare /  strategyShares);
        rewardTokenAddress.safeTransferFrom(address(this), msg.sender, stakeHolderAmount);
        strategyStakeRewards[strategy] -= stakeHolderAmount;
        emit StakeHolderClaimReward(
            msg.sender,
            stakeHolderAmount
        );
        return true;
    }

    function updateStakePercent(uint256 _stakePercent) external onlyRewardManager {
        stakePercent = _stakePercent;
    }
}

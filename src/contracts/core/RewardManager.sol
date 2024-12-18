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
        IERC20 _rewardTokenAddress
    ) RewardManagerStorage(_delegationManager, _stragegyManager, _rewardTokenAddress) {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _rewardManager, address _payFeeManager, uint256 _stakePercent) external initializer {
        payFeeManager = _payFeeManager;
        rewardManager = _rewardManager;
        stakePercent = _stakePercent;
        _transferOwnership(initialOwner);
    }

    function payFee(address strategy, address operator, uint256 baseFee) external onlyPayFeeManager {
        uint256 totalShares = IStrategyBase(strategy).totalShares();

        uint256 operatorShares = delegationManager.operatorShares(operator, IStrategyBase(strategy));

        require(
            totalShares > 0 && operatorShares > 0,
            "RewardManager operatorClaimReward: one of totalShares and operatorShares is zero"
        );

        uint256 operatorTotalFee = baseFee * operatorShares / totalShares;

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
        require(
            claimAmount > 0,
            "RewardManager operatorClaimReward: operator claim amount need more then zero"
        );
        require(
            rewardTokenAddress.balanceOf(address(this)) >= claimAmount,
            "RewardManager operatorClaimReward: Reward Token balance insufficient"
        );
        operatorRewards[msg.sender] = 0;
        rewardTokenAddress.safeTransfer(msg.sender, claimAmount);
        emit OperatorClaimReward(
            msg.sender,
            claimAmount
        );
        return true;
    }

    function stakeHolderClaimReward(address strategy) external returns (bool) {
        uint256 stakeHolderAmount = _stakeHolderAmount(msg.sender, strategy);
        require(
            stakeHolderAmount > 0,
            "RewardManager operatorClaimReward: stake holder amount need more then zero"
        );
        require(
            rewardTokenAddress.balanceOf(address(this)) >= stakeHolderAmount,
            "RewardManager operatorClaimReward: Reward Token balance insufficient"
        );
        strategyStakeRewards[strategy] -= stakeHolderAmount;
        rewardTokenAddress.safeTransfer(msg.sender, stakeHolderAmount);
        emit StakeHolderClaimReward(
            msg.sender,
            strategy,
            stakeHolderAmount
        );
        return true;
    }

    function getStakeHolderAmount(address strategy) external returns (uint256) {
        return _stakeHolderAmount(msg.sender, strategy);
    }

    function _stakeHolderAmount(address staker, address strategy) internal returns (uint256) {
        uint256 stakeHoldersShare = strategyManager.stakerStrategyShares(staker, IStrategyBase(strategy));
        uint256 strategyShares = IStrategyBase(strategy).totalShares();
        if (stakeHoldersShare == 0 ||strategyShares == 0) {
            return 0;
        }
        return strategyStakeRewards[strategy] * stakeHoldersShare / strategyShares;
    }


    function updateStakePercent(uint256 _stakePercent) external onlyRewardManager {
        stakePercent = _stakePercent;
    }
}

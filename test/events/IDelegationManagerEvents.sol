// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@/contracts/interfaces/IDelegationManager.sol";

interface IDelegationManagerEvents {
    struct OperatorDetails {
        address earningsReceiver;
        address delegationApprover;
        uint32 stakerOptOutWindowBlocks;
    }

    struct Withdrawal {
        address staker;
        address delegatedTo;
        address withdrawer;
        uint256 nonce;
        uint32 startBlock;
        IStrategyBase[] strategies;
        uint256[] shares;
    }

    event OperatorRegistered(address indexed operator, IDelegationManager.OperatorDetails operatorDetails);

    event OperatorDetailsModified(address indexed operator, IDelegationManager.OperatorDetails newOperatorDetails);

    event OperatorNodeUrlUpdated(address indexed operator, string metadataURI);

    event OperatorSharesIncreased(address indexed operator, address staker, IStrategyBase strategy, uint256 shares);

    event OperatorSharesDecreased(address indexed operator, address staker, IStrategyBase strategy, uint256 shares);

    event StakerDelegated(address indexed staker, address indexed operator);

    event StakerUndelegated(address indexed staker, address indexed operator);

    event StakerForceUndelegated(address indexed staker, address indexed operator);

    event WithdrawalQueued(bytes32 withdrawalRoot, IDelegationManager.Withdrawal withdrawal);

    event WithdrawalCompleted(address operator, address staker, IStrategyBase strategy, uint256 shares);

    event WithdrawalMigrated(bytes32 oldWithdrawalRoot, bytes32 newWithdrawalRoot);

    event MinWithdrawalDelayBlocksSet(uint256 previousValue, uint256 newValue);

    event StrategyWithdrawalDelayBlocksSet(IStrategyBase strategy, uint256 previousValue, uint256 newValue);
}

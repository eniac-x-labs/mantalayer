// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategyBase} from "./IStrategyBase.sol";

interface IStrategyManager {
    event Deposit(address staker, IERC20 mantaToken, IStrategyBase strategy, uint256 shares);

    event UpdatedThirdPartyTransfersForbidden(IStrategyBase strategy, bool value);


    event StrategyWhitelisterChanged(address previousAddress, address newAddress);

    event StrategyAddedToDepositWhitelist(IStrategyBase strategy);

    event StrategyRemovedFromDepositWhitelist(IStrategyBase strategy);

    function depositIntoStrategy(IStrategyBase strategy, IERC20 tokenAddress, uint256 amount) external returns (uint256 shares);

    function depositIntoStrategyWithSignature(
        IStrategyBase strategy,
        IERC20 tokenAddress,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 shares);

    function removeShares(address staker, IStrategyBase strategy, uint256 shares) external;

    function addShares(address staker, IERC20 mantaToken, IStrategyBase strategy, uint256 shares) external;

    function withdrawSharesAsTokens(address recipient, IStrategyBase strategy, uint256 shares, IERC20 tokenAddress) external;

    function stakerStrategyShares(address user, IStrategyBase strategy) external view returns (uint256 shares);

    function getDeposits(address staker) external view returns (IStrategyBase[] memory, uint256[] memory);

    function stakerStrategyListLength(address staker) external view returns (uint256);

    function addStrategiesToDepositWhitelist(
        IStrategyBase[] calldata strategiesToWhitelist,
        bool[] calldata thirdPartyTransfersForbiddenValues
    ) external;

    function removeStrategiesFromDepositWhitelist(IStrategyBase[] calldata strategiesToRemoveFromWhitelist) external;

    function strategyWhitelister() external view returns (address);

    function thirdPartyTransfersForbidden(IStrategyBase strategy) external view returns (bool);

    struct DeprecatedStruct_WithdrawerAndNonce {
        address withdrawer;
        uint96 nonce;
    }

    struct DeprecatedStruct_QueuedWithdrawal {
        IStrategyBase[] strategies;
        uint256[] shares;
        address staker;
        DeprecatedStruct_WithdrawerAndNonce withdrawerAndNonce;
        uint32 withdrawalStartBlock;
        address delegatedAddress;
    }

    function migrateQueuedWithdrawal(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external returns (bool, bytes32);

    function calculateWithdrawalRoot(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external pure returns (bytes32);
}

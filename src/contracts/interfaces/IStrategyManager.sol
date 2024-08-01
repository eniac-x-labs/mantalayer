// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategyManager {
    event Deposit(address staker, IERC20 weth, address strategy, uint256 shares);

    event StrategyWhitelisterChanged(address previousAddress, address newAddress);

    event StrategyAddedToDepositWhitelist(address strategy);

    event StrategyRemovedFromDepositWhitelist(address strategy);

    function depositIntoStrategy(address strategy, IERC20 tokenAddress, uint256 amount) external returns (uint256 shares);

    function depositIntoStrategyWithSignature(
        address strategy,
        IERC20 tokenAddress,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 shares);

    function removeShares(address staker, address strategy, uint256 shares) external;

    function addShares(address staker, IERC20 weth, address strategy, uint256 shares) external;

    function withdrawSharesAsWeth(address recipient, address strategy, uint256 shares, IERC20 weth) external;

    function getStakerStrategyShares(address user, address strategy) external view returns (uint256 shares);

    function getDeposits(address staker) external view returns (address[] memory, uint256[] memory);

    function stakerStrategyListLength(address staker) external view returns (uint256);

    function addStrategiesToDepositWhitelist(
        address[] calldata strategiesToWhitelist,
        bool[] calldata thirdPartyTransfersForbiddenValues
    ) external;

    function removeStrategiesFromDepositWhitelist(address[] calldata strategiesToRemoveFromWhitelist) external;

    function strategyWhitelister() external view returns (address);

    struct DeprecatedStruct_WithdrawerAndNonce {
        address withdrawer;
        uint96 nonce;
    }

    struct DeprecatedStruct_QueuedWithdrawal {
        address[] strategies;
        uint256[] shares;
        address staker;
        DeprecatedStruct_WithdrawerAndNonce withdrawerAndNonce;
        uint32 withdrawalStartBlock;
        address delegatedAddress;
    }

    function migrateQueuedWithdrawal(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external returns (bool, bytes32);

    function calculateWithdrawalRoot(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external pure returns (bytes32);
}

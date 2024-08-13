// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";

import "./StrategyManagerStorage.sol";
import "../../libraries/EIP1271SignatureUtils.sol";

contract StrategyManager is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, StrategyManagerStorage {
    using SafeERC20 for IERC20;

    uint8 internal constant PAUSED_DEPOSITS = 0;
    uint256 internal immutable ORIGINAL_CHAIN_ID;

    modifier onlyDelegationManager() {
        require(msg.sender == address(delegation), "onlyDelegationManager");
        _;
    }

    constructor(IDelegationManager _delegation) StrategyManagerStorage(_delegation) {
        _disableInitializers();
    }

    // EXTERNAL FUNCTIONS
    function initialize(
        address initialOwner,
        address initialStrategyWhitelister
    ) external initializer {
        _DOMAIN_SEPARATOR = _calculateDomainSeparator();
        _setStrategyWhitelister(initialStrategyWhitelister);
        _transferOwnership(initialOwner);
        _setStrategyWhitelister(initialStrategyWhitelister);
    }

    function depositIntoStrategy(
        IStrategyBase strategy,
        IERC20 tokenAddress,
        uint256 amount
    ) external nonReentrant returns (uint256 shares) {
        shares = _depositIntoStrategy(msg.sender, strategy, tokenAddress, amount);
    }

    function depositIntoStrategyWithSignature(
        IStrategyBase strategy,
        IERC20 tokenAddress,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external nonReentrant returns (uint256 shares) {
        require(
            !thirdPartyTransfersForbidden[strategy],
            "StrategyManager.depositIntoStrategyWithSignature: third transfers disabled"
        );
        require(expiry >= block.timestamp, "StrategyManager.depositIntoStrategyWithSignature: signature expired");
        uint256 nonce = nonces[staker];
        bytes32 structHash = keccak256(abi.encode(DEPOSIT_TYPEHASH, staker, strategy, tokenAddress, amount, nonce, expiry));
        unchecked {
            nonces[staker] = nonce + 1;
        }

        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator(), structHash));

        EIP1271SignatureUtils.checkSignature_EIP1271(staker, digestHash, signature);

        shares = _depositIntoStrategy(staker, strategy, tokenAddress, amount);
    }

    function removeShares(
        address staker,
        IStrategyBase strategy,
        uint256 shares
    ) external onlyDelegationManager {
        _removeShares(staker, strategy, shares);
    }

    function addShares(
        address staker,
        IERC20 weth,
        IStrategyBase strategy,
        uint256 shares
    ) external onlyDelegationManager {
        _addShares(staker, weth, strategy, shares);
    }

    function withdrawSharesAsTokens(
        address recipient,
        IStrategyBase strategy,
        uint256 shares,
        IERC20 tokenAddress
    ) external onlyDelegationManager {
        strategy.withdraw(recipient, tokenAddress, shares);
    }

    function getStakerStrategyShares(address user, IStrategyBase strategy) external view returns (uint256 shares) {
        return stakerStrategyShares[user][strategy];
    }

    function migrateQueuedWithdrawal(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external onlyDelegationManager returns(bool, bytes32) {
        bytes32 existingWithdrawalRoot = calculateWithdrawalRoot(queuedWithdrawal);
        bool isDeleted;
        if (withdrawalRootPending[existingWithdrawalRoot]) {
            withdrawalRootPending[existingWithdrawalRoot] = false;
            isDeleted = true;
        }
        return (isDeleted, existingWithdrawalRoot);
    }

    function setStrategyWhitelister(address newStrategyWhitelister) external onlyOwner {
        _setStrategyWhitelister(newStrategyWhitelister);
    }

    function addStrategiesToDepositWhitelist(
        IStrategyBase[] calldata strategiesToWhitelist,
        bool[] calldata thirdPartyTransfersForbiddenValues
    ) external onlyStrategyWhitelister {
        require(
            strategiesToWhitelist.length == thirdPartyTransfersForbiddenValues.length,
            "StrategyManager.addStrategiesToDepositWhitelist: array lengths do not match"
        );
        uint256 strategiesToWhitelistLength = strategiesToWhitelist.length;
        for (uint256 i = 0; i < strategiesToWhitelistLength; ) {
            if (!strategyIsWhitelistedForDeposit[strategiesToWhitelist[i]]) {
                strategyIsWhitelistedForDeposit[strategiesToWhitelist[i]] = true;
                emit StrategyAddedToDepositWhitelist(strategiesToWhitelist[i]);
                _setThirdPartyTransfersForbidden(strategiesToWhitelist[i], thirdPartyTransfersForbiddenValues[i]);
            }
            unchecked {
                ++i;
            }
        }
    }

    function removeStrategiesFromDepositWhitelist(
        IStrategyBase[] calldata strategiesToRemoveFromWhitelist
    ) external onlyStrategyWhitelister {
        uint256 strategiesToRemoveFromWhitelistLength = strategiesToRemoveFromWhitelist.length;
        for (uint256 i = 0; i < strategiesToRemoveFromWhitelistLength; ) {
            if (strategyIsWhitelistedForDeposit[strategiesToRemoveFromWhitelist[i]]) {
                strategyIsWhitelistedForDeposit[strategiesToRemoveFromWhitelist[i]] = false;
                emit StrategyRemovedFromDepositWhitelist(strategiesToRemoveFromWhitelist[i]);
                _setThirdPartyTransfersForbidden(strategiesToRemoveFromWhitelist[i], false);
            }
            unchecked {
                ++i;
            }
        }
    }

    // INTERNAL FUNCTIONS
    function _addShares(address staker, IERC20 weth, IStrategyBase strategy, uint256 shares) internal {
        require(staker != address(0), "StrategyManager._addShares: staker cannot be zero address");
        require(shares != 0, "StrategyManager._addShares: shares should not be zero!");

        if (stakerStrategyShares[staker][strategy] == 0) {
            require(
                stakerStrategyList[staker].length < MAX_STAKER_STRATEGY_LIST_LENGTH,
                "StrategyManager._addShares: deposit would exceed MAX_STAKER_STRATEGY_LIST_LENGTH"
            );
            stakerStrategyList[staker].push(strategy);
        }

        stakerStrategyShares[staker][strategy] += shares;

        emit Deposit(staker, weth, strategy, shares);
    }

    function _depositIntoStrategy(
        address staker,
        IStrategyBase strategy,
        IERC20 tokenAddress,
        uint256 amount
    ) internal onlyStrategiesWhitelistedForDeposit(strategy) returns (uint256 shares) {
        tokenAddress.safeTransferFrom(msg.sender, address(strategy), amount);

        shares = strategy.deposit(tokenAddress, amount);

        _addShares(staker, tokenAddress, strategy, shares);

        delegation.increaseDelegatedShares(staker, strategy, shares);

        return shares;
    }

    function _removeShares(
        address staker,
        IStrategyBase strategy,
        uint256 shareAmount
    ) internal returns (bool) {
        require(shareAmount != 0, "StrategyManager._removeShares: shareAmount should not be zero!");

        uint256 userShares = stakerStrategyShares[staker][strategy];

        require(shareAmount <= userShares, "StrategyManager._removeShares: shareAmount too high");
        unchecked {
            userShares = userShares - shareAmount;
        }

        stakerStrategyShares[staker][strategy] = userShares;

        if (userShares == 0) {
            _removeStrategyFromStakerStrategyList(staker, strategy);

            return true;
        }
        return false;
    }

    function _removeStrategyFromStakerStrategyList(
        address staker,
        IStrategyBase strategy
    ) internal {
        uint256 stratsLength = stakerStrategyList[staker].length;
        uint256 j = 0;
        for (; j < stratsLength; ) {
            if (stakerStrategyList[staker][j] == strategy) {
                stakerStrategyList[staker][j] = stakerStrategyList[staker][
                    stakerStrategyList[staker].length - 1
                    ];
                break;
            }
            unchecked { ++j; }
        }
        require(j != stratsLength, "StrategyManager._removeStrategyFromStakerStrategyList: strategy not found");
        stakerStrategyList[staker].pop();
    }

    function _setThirdPartyTransfersForbidden(IStrategyBase strategy, bool value) internal {
        emit UpdatedThirdPartyTransfersForbidden(strategy, value);
        thirdPartyTransfersForbidden[strategy] = value;
    }

    function _setStrategyWhitelister(address newStrategyWhitelister) internal {
        emit StrategyWhitelisterChanged(strategyWhitelister, newStrategyWhitelister);
        strategyWhitelister = newStrategyWhitelister;
    }

    // VIEW FUNCTIONS
    function getDeposits(address staker) external view returns (IStrategyBase[] memory, uint256[] memory) {
        uint256 strategiesLength = stakerStrategyList[staker].length;
        uint256[] memory shares = new uint256[](strategiesLength);
        for (uint256 i = 0; i < strategiesLength; ) {
            shares[i] = stakerStrategyShares[staker][stakerStrategyList[staker][i]];
            unchecked {
                ++i;
            }
        }
        return (stakerStrategyList[staker], shares);
    }

    function stakerStrategyListLength(address staker) external view returns (uint256) {
        return stakerStrategyList[staker].length;
    }

    function domainSeparator() public view returns (bytes32) {
        if (block.chainid == ORIGINAL_CHAIN_ID) {
            return _DOMAIN_SEPARATOR;
        } else {
            return _calculateDomainSeparator();
        }
    }

    function _calculateDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes("DappLink")), block.chainid, address(this)));
    }

    function calculateWithdrawalRoot(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) public pure returns (bytes32) {
        return (
            keccak256(
                abi.encode(
                    queuedWithdrawal.strategies,
                    queuedWithdrawal.shares,
                    queuedWithdrawal.staker,
                    queuedWithdrawal.withdrawerAndNonce,
                    queuedWithdrawal.withdrawalStartBlock,
                    queuedWithdrawal.delegatedAddress
                )
           )
        );
    }

    modifier onlyStrategyWhitelister() {
        require(
            msg.sender == strategyWhitelister,
            "StrategyManager.onlyStrategyWhitelister: not the strategyWhitelister"
        );
        _;
    }

    modifier onlyStrategiesWhitelistedForDeposit(IStrategyBase strategy) {
        require(
            strategyIsWhitelistedForDeposit[strategy],
            "StrategyManager.onlyStrategiesWhitelistedForDeposit: strategy not whitelisted"
        );
        _;
    }

}

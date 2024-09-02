// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@/access/Pausable.sol";
import "@/contracts/core/StrategyManagerStorage.sol";
import "@/contracts/interfaces/IDelegationManager.sol";

contract StrategyManagerMock is
    Initializable,
    IStrategyManager,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    Pausable
{
    IDelegationManager public delegation;
    address public strategyWhitelister;

    mapping(address => IStrategyBase[]) public strategiesToReturn;
    mapping(address => uint256[]) public sharesToReturn;

    mapping(IStrategyBase => bool) public strategyIsWhitelistedForDeposit;

    /// @notice Mapping: staker => cumulative number of queued withdrawals they have ever initiated. only increments (doesn't decrement)
    mapping(address => uint256) public cumulativeWithdrawalsQueued;

    mapping(IStrategyBase => bool) public thirdPartyTransfersForbidden;

    function setAddresses(IDelegationManager _delegation) external {
        delegation = _delegation;
    }

    function depositIntoStrategy(IStrategyBase strategy, IERC20 token, uint256 amount) external returns (uint256) {}

    function depositIntoStrategyWithSignature(
        IStrategyBase strategy,
        IERC20 token,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 shares) {}

    /// @notice Returns the current shares of `user` in `strategy`
    function stakerStrategyShares(address user, IStrategyBase strategy) external view returns (uint256 shares) {}

    /**
     * @notice mocks the return value of getDeposits
     * @param staker staker whose deposits are being mocked
     * @param _strategiesToReturn strategies to return in getDeposits
     * @param _sharesToReturn shares to return in getDeposits
     */
    function setDeposits(address staker, IStrategyBase[] calldata _strategiesToReturn, uint256[] calldata _sharesToReturn)
        external
    {
        require(_strategiesToReturn.length == _sharesToReturn.length, "StrategyManagerMock: length mismatch");
        strategiesToReturn[staker] = _strategiesToReturn;
        sharesToReturn[staker] = _sharesToReturn;
    }

    function setThirdPartyTransfersForbidden(IStrategyBase strategy, bool value) external {
        emit UpdatedThirdPartyTransfersForbidden(strategy, value);
        thirdPartyTransfersForbidden[strategy] = value;
    }

    /**
     * @notice Get all details on the staker's deposits and corresponding shares
     * @return (staker's strategies, shares in these strategies)
     */
    function getDeposits(address staker) external view returns (IStrategyBase[] memory, uint256[] memory) {
        return (strategiesToReturn[staker], sharesToReturn[staker]);
    }

    /// @notice Returns the array of strategies in which `staker` has nonzero shares
    function stakerStrats(address staker) external view returns (IStrategyBase[] memory) {}

    uint256 public stakerStrategyListLengthReturnValue;
    /// @notice Simple getter function that returns `stakerStrategyList[staker].length`.

    function stakerStrategyListLength(address /*staker*/ ) external view returns (uint256) {
        return stakerStrategyListLengthReturnValue;
    }

    function setStakerStrategyListLengthReturnValue(uint256 valueToSet) public {
        stakerStrategyListLengthReturnValue = valueToSet;
    }

    function setStrategyWhitelist(IStrategyBase strategy, bool value) external {
        strategyIsWhitelistedForDeposit[strategy] = value;
    }

    function removeShares(address staker, IStrategyBase strategy, uint256 shares) external {}

    function addShares(address staker, IERC20 token, IStrategyBase strategy, uint256 shares) external {}

    function withdrawSharesAsTokens(address recipient, IStrategyBase strategy, uint256 shares, IERC20 token) external {}

    /// @notice returns the enshrined beaconChainETH Strategy
    function beaconChainETHStrategy() external view returns (IStrategyBase) {}

    // function withdrawalDelayBlocks() external view returns (uint256) {}

    function addStrategiesToDepositWhitelist(
        IStrategyBase[] calldata strategiesToWhitelist,
        bool[] calldata thirdPartyTransfersForbiddenValues
    ) external {
        for (uint256 i = 0; i < strategiesToWhitelist.length; ++i) {
            strategyIsWhitelistedForDeposit[strategiesToWhitelist[i]] = true;
            thirdPartyTransfersForbidden[strategiesToWhitelist[i]] = thirdPartyTransfersForbiddenValues[i];
        }
    }

    function removeStrategiesFromDepositWhitelist(IStrategyBase[] calldata /*strategiesToRemoveFromWhitelist*/ )
        external
        pure
    {}

    function migrateQueuedWithdrawal(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external returns (bool, bytes32) {}

    function calculateWithdrawalRoot(DeprecatedStruct_QueuedWithdrawal memory queuedWithdrawal) external pure returns (bytes32) {}
}

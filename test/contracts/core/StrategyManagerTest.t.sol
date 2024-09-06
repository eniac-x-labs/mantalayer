// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import "@/contracts/interfaces/IStrategyBase.sol";
import "@/contracts/core/StrategyBase.sol";

import "../../DeployerMantaLayerTest.t.sol";
import "./DelegationManagerTest.t.sol";


contract StrategyManagerTest is DeployerMantaLayerTest {

    function setUp() public virtual {
        console.log("DelegationManagerTest setUp:", address(this));
        console.log("DelegationManagerTest msg.sender:", msg.sender);
        vm.chainId(17000);
        super._deployContractsLocal();
        console.log("DelegationManagerTest run end");
    }

    function test_removeShares() public {
        console.log("====================================================");
        console.log("==============test_removeShares==============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        address payFeeManager_address = staker;
        console.log("test_removeShares operator_address:", operator_address);
        console.log("test_removeShares staker_address:", staker_address);
        console.log("test_removeShares payFeeManager_address:", payFeeManager_address);

        test_addShares();

        uint256 before_shares = strategyManager.stakerStrategyShares(staker_address, IStrategyBase(address(strategyBase1)));
        console.log("test_removeShares before_shares:", before_shares);
        uint256 before_strategies_length = strategyManager.stakerStrategyListLength(staker_address);
        console.log("test_removeShares before_strategies_length:", before_strategies_length);

        vm.startPrank(address(delegationManager));
        strategyManager.removeShares(staker_address, IStrategyBase(address(strategyBase1)), 1e18);
        vm.stopPrank();

        uint256 after_shares = strategyManager.stakerStrategyShares(staker_address, IStrategyBase(address(strategyBase1)));
        console.log("test_removeShares after_shares:", after_shares);
        assertEq(after_shares, (before_shares - 1e18), "after_shares == 1e18");
        uint256 after_strategies_length = strategyManager.stakerStrategyListLength(staker_address);
        console.log("test_removeShares after_strategies_length:", after_strategies_length);
        assertEq(after_strategies_length, (before_strategies_length - 1), "after_strategies_length == 1");
    }

    function test_addShares() public {
        console.log("====================================================");
        console.log("====================test_addShares==================");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        address payFeeManager_address = staker;
        console.log("test_addShares operator_address:", operator_address);
        console.log("test_addShares staker_address:", staker_address);
        console.log("test_addShares payFeeManager_address:", payFeeManager_address);

        uint256 before_shares = strategyManager.stakerStrategyShares(staker_address, IStrategyBase(address(strategyBase1)));
        console.log("test_addShares before_shares:", before_shares);
        uint256 before_strategies_length = strategyManager.stakerStrategyListLength(staker_address);
        console.log("test_addShares before_strategies_length:", before_strategies_length);

        vm.startPrank(address(delegationManager));
        strategyManager.addShares(staker_address, IERC20(erc20TestToken), IStrategyBase(address(strategyBase1)), 1e18);
        vm.stopPrank();

        uint256 after_shares = strategyManager.stakerStrategyShares(staker_address, IStrategyBase(address(strategyBase1)));
        console.log("test_addShares after_shares:", after_shares);
        assertEq(after_shares - before_shares, 1e18, "after_shares == 1e18");
        uint256 after_strategies_length = strategyManager.stakerStrategyListLength(staker_address);
        console.log("test_addShares after_strategies_length:", after_strategies_length);
        assertEq(after_strategies_length - before_strategies_length, 1, "after_strategies_length == 1");
    }

    function test_withdrawSharesAsTokens() public {
        console.log("====================================================");
        console.log("====================test_withdrawSharesAsTokens==================");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        address payFeeManager_address = staker;
        console.log("test_withdrawSharesAsTokens operator_address:", operator_address);
        console.log("test_withdrawSharesAsTokens staker_address:", staker_address);
        console.log("test_withdrawSharesAsTokens payFeeManager_address:", payFeeManager_address);

        _depositIntoStrategy();

        uint256 before_strategyBase1_balance = erc20TestToken.balanceOf(address(strategyBase1));
        console.log("test_withdrawSharesAsTokens before_strategyBase1_balance:", before_strategyBase1_balance);
        uint256 before_staker_address_balance = erc20TestToken.balanceOf(address(staker_address));
        console.log("test_withdrawSharesAsTokens before_staker_address_balance:", before_staker_address_balance);

        vm.startPrank(address(delegationManager));
        strategyManager.withdrawSharesAsTokens(staker_address, IStrategyBase(address(strategyBase1)),
            1e18, IERC20(address(erc20TestToken)));
        vm.stopPrank();

        uint256 after_strategyBase1_balance = erc20TestToken.balanceOf(address(strategyBase1));
        console.log("test_withdrawSharesAsTokens after_strategyBase1_balance:", after_strategyBase1_balance);
        assertEq(after_strategyBase1_balance + before_strategyBase1_balance, 1e18, "test_withdrawSharesAsTokens after_strategyBase1_balance");
        uint256 after_staker_address_balance = erc20TestToken.balanceOf(address(staker_address));
        console.log("test_withdrawSharesAsTokens after_staker_address_balance:", after_staker_address_balance);
        assertEq(after_staker_address_balance - before_staker_address_balance, 1e18, "test_withdrawSharesAsTokens after_staker_address_balance");
    }

    function test_migrateQueuedWithdrawal() public {
        console.log("====================================================");
        console.log("====================test_migrateQueuedWithdrawal==================");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        address payFeeManager_address = staker;
        console.log("test_migrateQueuedWithdrawal operator_address:", operator_address);
        console.log("test_migrateQueuedWithdrawal staker_address:", staker_address);
        console.log("test_migrateQueuedWithdrawal payFeeManager_address:", payFeeManager_address);

        StrategyBase[] memory deployedStrategyArrayMemory = new StrategyBase[](1);
        deployedStrategyArrayMemory[0] = strategyBase1;

        uint256[] memory withdrawalDelayBlocksMemory = new uint256[](1);
        withdrawalDelayBlocksMemory[0] = 7200;

        IStrategyBase[] memory deployedStrategyArray = new IStrategyBase[](deployedStrategyArrayMemory.length);
        for (uint256 i = 0; i < deployedStrategyArrayMemory.length; i++) {
            deployedStrategyArray[i] = IStrategyBase(address(deployedStrategyArrayMemory[i]));
        }

        IStrategyManager.DeprecatedStruct_WithdrawerAndNonce memory nonce = IStrategyManager.DeprecatedStruct_WithdrawerAndNonce({
            withdrawer: staker_address,
            nonce: 1
        });

        IStrategyManager.DeprecatedStruct_QueuedWithdrawal memory withdrawal = IStrategyManager.DeprecatedStruct_QueuedWithdrawal({
            strategies: deployedStrategyArray,
            shares: withdrawalDelayBlocksMemory,
            staker: staker_address,
            withdrawerAndNonce: nonce,
            withdrawalStartBlock: 101,
            delegatedAddress: DELEGATION_APPROVER
        });

        vm.startPrank(address(delegationManager));
        (bool isDeleted, bytes32 existingWithdrawalRoot) = strategyManager.migrateQueuedWithdrawal(withdrawal);
        vm.stopPrank();

        console.log("test_migrateQueuedWithdrawal after_isDeleted:", isDeleted);
        console.log("test_migrateQueuedWithdrawal after_existingWithdrawalRoot:");
        console.logBytes32(existingWithdrawalRoot);

        assertEq(isDeleted, false, "test_migrateQueuedWithdrawal isDeleted");
        assertEq(existingWithdrawalRoot, 0x3710c18d29944b27f5b880c2bde757314f62450de23b631e94e025b428760132, "test_migrateQueuedWithdrawal existingWithdrawalRoot");
    }

    function test_setStrategyWhitelister() public {
        console.log("====================================================");
        console.log("====================test_setStrategyWhitelister==================");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        address payFeeManager_address = staker;
        console.log("test_setStrategyWhitelister operator_address:", operator_address);
        console.log("test_setStrategyWhitelister staker_address:", staker_address);
        console.log("test_setStrategyWhitelister payFeeManager_address:", payFeeManager_address);

        vm.startPrank(address(staker));
        strategyManager.setStrategyWhitelister(EARNINGS_RECEIVER);
        vm.stopPrank();

        console.log("test_setStrategyWhitelister strategyWhitelister:", strategyManager.strategyWhitelister());
        assertEq(strategyManager.strategyWhitelister(), EARNINGS_RECEIVER, "test_setStrategyWhitelister true");
    }

    function test_addStrategiesToDepositWhitelist() public {
        console.log("====================================================");
        console.log("====================test_migrateQueuedWithdrawal==================");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        address payFeeManager_address = staker;
        console.log("test_addStrategiesToDepositWhitelist operator_address:", operator_address);
        console.log("test_addStrategiesToDepositWhitelist staker_address:", staker_address);
        console.log("test_addStrategiesToDepositWhitelist payFeeManager_address:", payFeeManager_address);

        test_removeStrategiesFromDepositWhitelist();

        IStrategyBase[] memory strategiesToWhitelist = new IStrategyBase[](1);
        strategiesToWhitelist[0] = strategyBase1;

        bool[] memory thirdPartyTransfersForbiddenValues = new bool[](1);
        thirdPartyTransfersForbiddenValues[0] = true;

        vm.startPrank(staker);
        strategyManager.addStrategiesToDepositWhitelist(strategiesToWhitelist, thirdPartyTransfersForbiddenValues);
        vm.stopPrank();

        assertTrue(strategyManager.strategyIsWhitelistedForDeposit(strategyBase1));

        assertTrue(strategyManager.thirdPartyTransfersForbidden(strategyBase1));
    }

    function test_removeStrategiesFromDepositWhitelist() public {
        console.log("====================================================");
        console.log("============test_migrateQueuedWithdrawal============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        address payFeeManager_address = staker;
        console.log("test_migrateQueuedWithdrawal operator_address:", operator_address);
        console.log("test_migrateQueuedWithdrawal staker_address:", staker_address);
        console.log("test_migrateQueuedWithdrawal payFeeManager_address:", payFeeManager_address);

        IStrategyBase[] memory strategiesToRemoveFromWhitelist = new IStrategyBase[](1);
        strategiesToRemoveFromWhitelist[0] = strategyBase1;

        vm.prank(staker_address);
        strategyManager.removeStrategiesFromDepositWhitelist(strategiesToRemoveFromWhitelist);

        assertFalse(strategyManager.strategyIsWhitelistedForDeposit(strategyBase1));
        assertFalse(strategyManager.thirdPartyTransfersForbidden(strategyBase1));
    }


}

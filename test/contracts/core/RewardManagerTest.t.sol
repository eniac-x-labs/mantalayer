// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import "@/contracts/core/RewardManager.sol";
import "@/contracts/core/RewardManagerStorage.sol";

import "./DelegationManagerTest.t.sol";

contract RewardManagerTest is DeployerMantaLayerTest {

    function setUp() public virtual {
        console.log("RewardManagerTest setUp:", address(this));
        console.log("RewardManagerTest msg.sender:", msg.sender);
        vm.chainId(17000);
        super._deployContractsLocal();
        console.log("RewardManagerTest run end");
    }

    function test_payFee() public {
        console.log("====================================================");
        console.log("========test_payFee============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        address payFeeManager_address = staker;
        console.log("test_payFee operator_address:", operator_address);
        console.log("test_payFee staker_address:", staker_address);
        console.log("test_payFee payFeeManager_address:", payFeeManager_address);


    }

    function test_operatorClaimReward() public {
        _depositIntoStrategy();

        console.log("====================================================");
        console.log("==============test_operatorClaimReward==============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        address payFeeManager_address = staker;
        console.log("test_operatorClaimReward operator_address:", operator_address);
        console.log("test_operatorClaimReward staker_address:", staker_address);
        console.log("test_operatorClaimReward payFeeManager_address:", payFeeManager_address);

        vm.startPrank(staker_address);

//       bool flag = rewardManager.operatorClaimReward();


        vm.stopPrank();

    }

    function test_stakeHolderClaimReward() public {

    }

    function test_getStakeHolderAmount() public {

    }

    function test_updateStakePercent() public {
        console.log("====================================================");
        console.log("==============test_updateStakePercent==============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        address payFeeManager_address = staker;
        console.log("test_updateStakePercent operator_address:", operator_address);
        console.log("test_updateStakePercent staker_address:", staker_address);
        console.log("test_updateStakePercent payFeeManager_address:", payFeeManager_address);

        vm.startPrank(payFeeManager_address);

        uint256 before_stakePercent = rewardManager.stakePercent();
        console.log("test_updateStakePercent before_stakePercent:", before_stakePercent);
        rewardManager.updateStakePercent(1000);
        uint256 after_stakePercent = rewardManager.stakePercent();
        console.log("test_updateStakePercent after_stakePercent:", after_stakePercent);

        assertEq(after_stakePercent, 1000, "stakePercent == 1000");

        vm.stopPrank();
    }

}

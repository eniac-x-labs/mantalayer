// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import "@/contracts/interfaces/IStrategyBase.sol";
import {IDelegationManager} from "@/contracts/interfaces/IDelegationManager.sol";
import {DeployerBasicTest} from "./DeployerBasicTest.t.sol";
import "@/contracts/interfaces/ISignatureUtils.sol";
import "@/contracts/core/StrategyBase.sol";

contract DeployerMantaLayerTest is DeployerBasicTest {

    function getAddressByIndex(uint32 index) public returns (address addr) {
        uint256 privateKey = vm.deriveKey("test test test test test test test test test test test junk", index);
        console.log("getAddressByIndex privateKey = ", privateKey);
        address addr = vm.addr(privateKey);
        console.log("getAddressByIndex addr = ", msg.sender);
        return addr;
    }

    function getPrivateKeyByIndex(uint32 index) public returns (uint256 privateKey) {
        uint256 privateKey = vm.deriveKey("test test test test test test test test test test test junk", index);
        console.log("getPrivateKeyByIndex privateKey = ", privateKey);
        return privateKey;
    }

    function buildSignatureByIndex(
        uint32 index,
        address staker,
        address operator,
        uint256 nonce,
        uint256 input_expiry,
        bytes32 domainSeparator,
        bytes32 typeHash
    ) public returns (ISignatureUtils.SignatureWithExpiry memory) {

        uint256 privateKey = getPrivateKeyByIndex(index);
        console.log("buildSignatureByIndex privateKey = ", privateKey);
        address addr = vm.addr(privateKey);
        console.log("buildSignatureByIndex addr = ", addr);

        // build structHash
        bytes32 structHash = keccak256(
            abi.encode(typeHash, staker, operator, nonce, input_expiry)
        );
        // build digestHash
        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digestHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        console.log("buildSignatureByIndex Signature length:", signature.length);

        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils.SignatureWithExpiry({
            signature: signature,
            expiry: input_expiry
        });

        return signatureWithExpiry;
    }

    function _deployContractsLocal() public {
        _parseInitialDeploymentParams();

//        EOAowner = msg.sender;
        executorMultisig = staker;
        operationsMultisig = staker;
        pauserMultisig = staker;
        communityMultisig = staker;
        timelock = staker;
        STRATEGY_MANAGER_WHITELISTER = staker;

        console.log("DeployerMantaLayerTest msg.sender = ", msg.sender);
        console.log("DeployerMantaLayerTest EOAowner = ", staker);
        console.log("DeployerMantaLayerTest executorMultisig = ", executorMultisig);
        console.log("DeployerMantaLayerTest operationsMultisig = ", operationsMultisig);
        console.log("DeployerMantaLayerTest pauserMultisig = ", pauserMultisig);
        console.log("DeployerMantaLayerTest communityMultisig = ", communityMultisig);
        console.log("DeployerMantaLayerTest STRATEGY_MANAGER_WHITELISTER = ", STRATEGY_MANAGER_WHITELISTER);

        _deployFromScratch();

        // Sanity Checks
        _verifyContractPointers();
        _verifyImplementations();
        _verifyContractsInitialized({isInitialDeployment: true});
        // override to check contract.owner() is EOAowner instead
        _verifyInitializationParams();

//        logAndOutputContractAddresses("script/output/DeploymentOutput.config.json");
    }

    function _registerAsOperator() public {
        console.log("DelegationManagerTest test_registerAsOperator :", address(this));
        console.log("DelegationManagerTest test_registerAsOperator address(delegationManager):", address(delegationManager));
        console.log("DelegationManagerTest msg.sender :", msg.sender);

        address operator_address = operator;
        address staker_address = staker;

        uint32 temp_stakerOptOutWindowBlocks = 100;

        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            earningsReceiver: operator_address,
            delegationApprover: operator_address,
            stakerOptOutWindowBlocks: temp_stakerOptOutWindowBlocks
        });

        console.log("DelegationManagerTest msg.sender2 :", msg.sender);

        bool before_delegationApproverSaltIsSpent = delegationManager.delegationApproverSaltIsSpent(operator_address, bytes32(0));
        console.log("test_registerAsOperator before_delegationApproverSaltIsSpent:", before_delegationApproverSaltIsSpent);

        vm.startPrank(operator_address);
        delegationManager.registerAsOperator(operatorDetails, "https://www.bilibili.com/");
        vm.stopPrank();

        IDelegationManager.OperatorDetails memory result = delegationManager.operatorDetails(operator_address);

        address after_earningsReceiver = delegationManager.earningsReceiver(operator_address);
        console.log("test_registerAsOperator after_earningsReceiver:", address(after_earningsReceiver));
        assertTrue(after_earningsReceiver == operator_address, "after_earningsReceiver == operator_address");

        address after_delegationApprover = delegationManager.delegationApprover(operator_address);
        console.log("test_registerAsOperator after_delegationApprover:", address(after_delegationApprover));
        assertTrue(after_delegationApprover == operator_address, "after_delegationApprover == operator_address");

        uint256 after_stakerOptOutWindowBlocks = delegationManager.stakerOptOutWindowBlocks(operator_address);
        console.log("test_registerAsOperator after_stakerOptOutWindowBlocks:", after_stakerOptOutWindowBlocks);
        assertTrue(after_stakerOptOutWindowBlocks == temp_stakerOptOutWindowBlocks, "after_stakerOptOutWindowBlocks == temp_stakerOptOutWindowBlocks");

//        bool after_delegationApproverSaltIsSpent = delegationManager.delegationApproverSaltIsSpent(DELEGATION_APPROVER, bytes32(0));
//        console.log("test_registerAsOperator after_delegationApproverSaltIsSpent:", after_delegationApproverSaltIsSpent);
//        assertTrue(after_delegationApproverSaltIsSpent, "after_delegationApproverSaltIsSpent");

        address after_operator = delegationManager.delegatedTo(operator_address);
        console.log("test_registerAsOperator after_operator:", after_operator);
        console.log("test_registerAsOperator operator_address:", operator_address);
        assertTrue(operator == after_operator, "operator == after_operator");
    }


    function _depositIntoStrategy() public {
        vm.deal(address(staker), 1111 ether);

        console.log("test_depositIntoStrategy delegationManager:", address(delegationManager));

        _registerAsOperator();

        console.log("test_depositIntoStrategy :", address(this));
        console.log("test_depositIntoStrategy msg.sender:", msg.sender);

        address operator_address = staker;
        address staker_address = staker;

        address strategy_address = address(strategyBase1);
        StrategyBase strategy = strategyBase1;
        console.log("test_depositIntoStrategy underlyingToken :", address(strategy.underlyingToken()));

        address tokenAddress = address(erc20TestToken);
        IERC20 tokenAddressErc20 = IERC20(tokenAddress);

        uint256 before_EOAowner_balance = tokenAddressErc20.balanceOf(staker);
        console.log("test_depositIntoStrategy before_EOAowner_balance :", before_EOAowner_balance);
        uint256 before_strategy_balance = tokenAddressErc20.balanceOf(strategy_address);
        console.log("test_depositIntoStrategy before_strategy_balance :", before_strategy_balance);
        uint256 old_shares = delegationManager.operatorShares(staker_address, IStrategyBase(address(strategyBase1)));
        console.log("test_depositIntoStrategy old_shares :", old_shares);

        vm.startPrank(staker);
        tokenAddressErc20.approve(address(strategyManager), 100 * 1e18);
        uint256 shares = strategyManager.depositIntoStrategy(strategy, tokenAddressErc20, 1 * 1e18);
        vm.stopPrank();

        console.log("test_depositIntoStrategy shares :", shares);

        uint256 after_EOAowner_balance = tokenAddressErc20.balanceOf(staker);
        console.log("test_depositIntoStrategy after_EOAowner_balance :", after_EOAowner_balance);
        uint256 after_strategy_balance = tokenAddressErc20.balanceOf(strategy_address);
        console.log("test_depositIntoStrategy after_strategy_balance :", after_strategy_balance);
        uint256 new_shares = delegationManager.operatorShares(operator_address, IStrategyBase(address(strategyBase1)));
        console.log("test_depositIntoStrategy new_shares :", new_shares);

        assertTrue((after_strategy_balance - 1e18) == before_strategy_balance, "strategy_balance");
        assertTrue((after_EOAowner_balance + 1e18) == before_EOAowner_balance, "EOAowner_balance");
//        assertTrue(new_shares == 1e18, "new_shares");
//        need to  delegatedTo
    }
}

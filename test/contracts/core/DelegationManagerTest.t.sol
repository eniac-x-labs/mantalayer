// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";

import {IDelegationManager} from "@/contracts/interfaces/IDelegationManager.sol";
import {IStrategyBase} from "@/contracts/interfaces/IStrategyBase.sol";
import {DeployerMantaLayerTest} from "../../DeployerMantaLayerTest.t.sol";
import "@/contracts/core/StrategyBase.sol";
import "@/contracts/interfaces/ISignatureUtils.sol";
import {StrategyManagerTest} from "./StrategyManagerTest.t.sol";
import "@/contracts/interfaces/IDelegationManager.sol";

contract DelegationManagerTest is DeployerMantaLayerTest {
    function setUp() public virtual {
        console.log("DelegationManagerTest setUp:", address(this));
        console.log("DelegationManagerTest msg.sender:", msg.sender);
        vm.chainId(17000);
        super._deployContractsLocal();
        console.log("DelegationManagerTest run end");
    }

    function test_registerAsOperator() public {
        _registerAsOperator();
    }

    function test_modifyOperatorDetails() public {
        _registerAsOperator();

        address operator_address = operator;
        address staker_address = staker;

        uint32 temp_stakerOptOutWindowBlocks = 101;
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            earningsReceiver: EARNINGS_RECEIVER,
            delegationApprover: DELEGATION_APPROVER,
            stakerOptOutWindowBlocks: temp_stakerOptOutWindowBlocks
        });

        vm.startPrank(operator_address);
        delegationManager.modifyOperatorDetails(operatorDetails);
        vm.stopPrank();

        address result_earningsReceiver = delegationManager.earningsReceiver(operator_address);
        console.log("test_registerAsOperator result_earningsReceiver:", address(result_earningsReceiver));
        assertTrue(result_earningsReceiver == EARNINGS_RECEIVER, "result_earningsReceiver == TEST_ZERO_ADDRESS");

        address result_delegationApprover = delegationManager.delegationApprover(operator_address);
        console.log("test_registerAsOperator result_delegationApprover:", address(result_delegationApprover));
        assertTrue(result_delegationApprover == DELEGATION_APPROVER, "result_delegationApprover == TEST_ZERO_ADDRESS");

        uint256 result_stakerOptOutWindowBlocks = delegationManager.stakerOptOutWindowBlocks(operator_address);
        console.log("test_registerAsOperator result_stakerOptOutWindowBlocks:", result_stakerOptOutWindowBlocks);
        assertTrue(result_stakerOptOutWindowBlocks == temp_stakerOptOutWindowBlocks, "result_stakerOptOutWindowBlocks == temp_stakerOptOutWindowBlocks");
    }

    function test_updateOperatorNodeUrl() public {
        test_registerAsOperator();
        address operator_address = operator;
        vm.startPrank(operator_address);
        delegationManager.updateOperatorNodeUrl("https://github.com/");
        vm.stopPrank();
    }

    function test_delegateTo_1() public {
        console.log("====================================================");
        console.log("==================test_delegateTo_1=================");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        console.log("test_delegateTo operator_address:", operator_address);
        console.log("test_delegateTo staker_address:", staker_address);

        test_registerAsOperator();

        address before_delegationApprover = delegationManager.operatorDetails(operator_address).delegationApprover;
        console.log("test_delegateTo before_delegationApprover:", before_delegationApprover);
        bool before_spent_flag = delegationManager.delegationApproverSaltIsSpent(before_delegationApprover, bytes32(0));
        console.log("test_delegateTo before_spent_flag:", before_spent_flag);
        address before_operator = delegationManager.delegatedTo(staker_address);
        console.log("test_delegateTo before_operator:", before_operator);
        (IStrategyBase[] memory before_strategies, uint256[] memory before_shares)
        = delegationManager.getDelegatableShares(staker_address);
        console.log("test_delegateTo before_strategies.length:", before_strategies.length);
        console.log("test_delegateTo before_shares.length:", before_shares.length);

        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry;
        vm.startPrank(staker_address);
//        delegationManager.delegateTo(operator_address, signatureWithExpiry, bytes32(0));
        vm.stopPrank();

        address after_delegationApprover = delegationManager.operatorDetails(operator_address).delegationApprover;
        console.log("test_delegateTo after_delegationApprover:", after_delegationApprover);

        bool after_spent_flag = delegationManager.delegationApproverSaltIsSpent(before_delegationApprover, bytes32(0));
        console.log("test_delegateTo after_spent_flag:", after_spent_flag);

        address after_operator = delegationManager.delegatedTo(staker_address);
        console.log("test_delegateTo after_operator:", after_operator);

        (IStrategyBase[] memory after_strategies, uint256[] memory after_shares)
        = delegationManager.getDelegatableShares(staker_address);
        console.log("test_delegateTo after_strategies.length:", after_strategies.length);
        console.log("test_delegateTo after_shares.length:", after_shares.length);
    }

//    function test_delegateTo_2() public {
//        console.log("====================================================");
//        console.log("==================test_delegateTo_2=================");
//        console.log("====================================================");
//        address operator_address = operator;
//        address staker_address = staker;
//        console.log("test_delegateTo operator_address:", operator_address);
//        console.log("test_delegateTo staker_address:", staker_address);
//
//        test_registerAsOperator();
//
//        address before_delegationApprover = delegationManager.operatorDetails(operator_address).delegationApprover;
//        console.log("test_delegateTo before_delegationApprover:", before_delegationApprover);
//        bool before_spent_flag = delegationManager.delegationApproverSaltIsSpent(before_delegationApprover, bytes32(0));
//        console.log("test_delegateTo before_spent_flag:", before_spent_flag);
//        address before_operator = delegationManager.delegatedTo(staker_address);
//        console.log("test_delegateTo before_operator:", before_operator);
//        (IStrategyBase[] memory before_strategies, uint256[] memory before_shares)
//        = delegationManager.getDelegatableShares(staker_address);
//        console.log("test_delegateTo before_strategies.length:", before_strategies.length);
//        console.log("test_delegateTo before_shares.length:", before_shares.length);
//
//        uint256 staker_priKey = getPrivateKeyByIndex(staker_index);
//        address temp_staker_addr = vm.addr(staker_priKey);
//        console.log("test_delegateTo temp_staker_addr:", temp_staker_addr);
//
//        uint256 approverExpiry = block.timestamp + 3600;
//        bytes32 approverSalt = keccak256(abi.encodePacked(block.timestamp, msg.sender));
//
////        bytes32 dataToSign = delegationManager.calculateDelegationApprovalDigestHash(
////            staker_address,
////            operator_address,
////            before_delegationApprover,
////            approverSalt,
////            approverExpiry
////        );
////        uint256 staker_priKey = getPrivateKeyByIndex(staker_index);
////        address temp_staker_addr = vm.addr(staker_priKey);
////        console.log("test_delegateTo temp_staker_addr:", temp_staker_addr);
////
////        (uint8 v, bytes32 r, bytes32 s) = vm.sign(staker_priKey, dataToSign);
////        bytes memory approverSignature = abi.encodePacked(r, s, v);
////
////        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils.SignatureWithExpiry({
////            signature: approverSignature,
////            expiry: approverExpiry
////        });
////        vm.startPrank(staker_address);
////        delegationManager.delegateTo(operator_address, signatureWithExpiry, bytes32(0));
////        vm.stopPrank();
//
//
//
////        uint256 nonceBefore = delegationManager.stakerNonce(staker);
////        bytes32 structHash = keccak256(
////            abi.encode(delegationManager.STAKER_DELEGATION_TYPEHASH(), staker, operator, nonceBefore, type(uint256).max)
////        );
////        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", delegationManager.domainSeparator(), structHash));
////        bytes memory signature;
////        {
////            (uint8 v, bytes32 r, bytes32 s) = vm.sign(staker_priKey, digestHash);
////            signature = abi.encodePacked(r, s, v);
////        }
////        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils.SignatureWithExpiry({
////            signature: signature,
////            expiry: type(uint256).max
////        });
//
//
//
////        uint256 approverExpiry = block.timestamp + 3600;
//////        bytes32 approverSalt = keccak256(abi.encodePacked(block.timestamp, msg.sender));
////
////        uint256 staker_priKey = getPrivateKeyByIndex(staker_index);
////        address temp_staker_addr = vm.addr(staker_priKey);
////        console.log("test_delegateTo temp_staker_addr:", temp_staker_addr);
////
////        ISignatureUtils.SignatureWithExpiry memory approverSignatureAndExpiry;
////        approverSignatureAndExpiry.expiry = approverExpiry;
////        {
////            bytes32 digestHash = delegationManager.calculateDelegationApprovalDigestHash(
////                staker_address,
////                operator_address,
////                before_delegationApprover,
////                emptySalt,
////                approverExpiry
////            );
////            (uint8 v, bytes32 r, bytes32 s) = vm.sign(staker_priKey, digestHash);
////            // mess up the signature by flipping v's parity
////            v = (v == 27 ? 28 : 27);
////            approverSignatureAndExpiry.signature = abi.encodePacked(r, s, v);
////        }
//
//        ISignatureUtils.SignatureWithExpiry memory approverSignatureAndExpiry = _getApproverSignature(
//            staker_priKey,
//            staker,
//            operator_address,
//            approverSalt,
//            approverExpiry
//        );
////        // calculate the staker signature
////        ISignatureUtils.SignatureWithExpiry memory stakerSignatureAndExpiry = _getStakerSignature(
////            staker_priKey,
////            operator_address,
////            approverExpiry
////        );
//        vm.startPrank(staker_address);
//        delegationManager.delegateTo(operator, approverSignatureAndExpiry, emptySalt);
//        vm.stopPrank();
//
//        address after_delegationApprover = delegationManager.operatorDetails(operator_address).delegationApprover;
//        console.log("test_delegateTo after_delegationApprover:", after_delegationApprover);
//
//        bool after_spent_flag = delegationManager.delegationApproverSaltIsSpent(before_delegationApprover, bytes32(0));
//        console.log("test_delegateTo after_spent_flag:", after_spent_flag);
//
//        address after_operator = delegationManager.delegatedTo(staker_address);
//        console.log("test_delegateTo after_operator:", after_operator);
//
//        (IStrategyBase[] memory after_strategies, uint256[] memory after_shares)
//        = delegationManager.getDelegatableShares(staker_address);
//        console.log("test_delegateTo after_strategies.length:", after_strategies.length);
//        console.log("test_delegateTo after_shares.length:", after_shares.length);
//    }

    /**
     * @notice internal function for calculating a signature from the staker corresponding to `_stakerPrivateKey`, delegating them to
     * the `operator`, and expiring at `expiry`.
     */
    function _getStakerSignature(
        uint256 _stakerPrivateKey,
        address operator,
        uint256 expiry
    ) internal view returns (ISignatureUtils.SignatureWithExpiry memory stakerSignatureAndExpiry) {
        address staker = vm.addr(_stakerPrivateKey);
        stakerSignatureAndExpiry.expiry = expiry;
        {
            bytes32 digestHash = delegationManager.calculateCurrentStakerDelegationDigestHash(staker, operator, expiry);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_stakerPrivateKey, digestHash);
            stakerSignatureAndExpiry.signature = abi.encodePacked(r, s, v);
        }
        return stakerSignatureAndExpiry;
    }

    /**
   * @notice internal function for calculating a signature from the delegationSigner corresponding to `_delegationSignerPrivateKey`, approving
     * the `staker` to delegate to `operator`, with the specified `salt`, and expiring at `expiry`.
     */
    function _getApproverSignature(
        uint256 _delegationSignerPrivateKey,
        address staker,
        address operator,
        bytes32 salt,
        uint256 expiry
    ) internal view returns (ISignatureUtils.SignatureWithExpiry memory approverSignatureAndExpiry) {
        approverSignatureAndExpiry.expiry = expiry;
        {
            bytes32 digestHash = delegationManager.calculateDelegationApprovalDigestHash(
                staker,
                operator,
                delegationManager.delegationApprover(operator),
                salt,
                expiry
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_delegationSignerPrivateKey, digestHash);
            approverSignatureAndExpiry.signature = abi.encodePacked(r, s, v);
        }
        return approverSignatureAndExpiry;
    }

//    function test_delegateTo_3() public {
//        console.log("====================================================");
//        console.log("=============test_delegateToBySignature=============");
//        console.log("====================================================");
//        address operator_address = operator;
//        address staker_address = staker;
//        console.log("test_delegateToBySignature operator_address:", operator_address);
//        console.log("test_delegateToBySignature staker_address:", staker_address);
//
//        test_registerAsOperator();
//
//        address before_delegationApprover = delegationManager.operatorDetails(operator_address).delegationApprover;
//        console.log("test_delegateToBySignature before_delegationApprover:", before_delegationApprover);
//        bool before_spent_flag = delegationManager.delegationApproverSaltIsSpent(before_delegationApprover, bytes32(0));
//        console.log("test_delegateToBySignature before_spent_flag:", before_spent_flag);
//        address before_operator = delegationManager.delegatedTo(staker_address);
//        console.log("test_delegateToBySignature before_operator:", before_operator);
//        (IStrategyBase[] memory before_strategies, uint256[] memory before_shares)
//        = delegationManager.getDelegatableShares(staker_address);
//        console.log("test_delegateToBySignature before_strategies.length:", before_strategies.length);
//        console.log("test_delegateToBySignature before_shares.length:", before_shares.length);
//
//        uint256 staker_priKey = getPrivateKeyByIndex(staker_index);
//        address temp_staker_addr = vm.addr(staker_priKey);
//        console.log("test_delegateToBySignature temp_staker_addr:", temp_staker_addr);
//
//        uint256 delegation_prikey = getPrivateKeyByIndex(DELEGATION_APPROVER_index);
//        address temp_delegation_addr = vm.addr(delegation_prikey);
//        console.log("test_delegateToBySignature temp_delegation_addr:", temp_delegation_addr);
//
//        uint256 approverExpiry = block.timestamp + 3600;
//        bytes32 approverSalt = keccak256(abi.encodePacked(block.timestamp, msg.sender));
//
//        uint256 expiry = type(uint256).max;
//        ISignatureUtils.SignatureWithExpiry memory approverSignatureAndExpiry = _getApproverSignature(
//            delegation_prikey,
//            staker,
//            operator,
//            emptySalt,
//            expiry
//        );
//        vm.prank(staker);
//        delegationManager.delegateTo(operator, approverSignatureAndExpiry, emptySalt);
//    }

//    function test_delegateToBySignature_1() public {
//        console.log("====================================================");
//        console.log("============test_delegateToBySignature_1============");
//        console.log("====================================================");
//        address operator_address = operator;
//        address staker_address = staker;
//        console.log("test_delegateToBySignature_1 operator_address:", operator_address);
//        console.log("test_delegateToBySignature_1 staker_address:", staker_address);
//
//        test_registerAsOperator();
//
//        address before_delegationApprover = delegationManager.operatorDetails(operator_address).delegationApprover;
//        console.log("test_delegateToBySignature_1 before_delegationApprover:", before_delegationApprover);
//        bool before_spent_flag = delegationManager.delegationApproverSaltIsSpent(before_delegationApprover, bytes32(0));
//        console.log("test_delegateToBySignature_1 before_spent_flag:", before_spent_flag);
//        address before_operator = delegationManager.delegatedTo(staker_address);
//        console.log("test_delegateToBySignature_1 before_operator:", before_operator);
//        (IStrategyBase[] memory before_strategies, uint256[] memory before_shares)
//        = delegationManager.getDelegatableShares(staker_address);
//        console.log("test_delegateToBySignature_1 before_strategies.length:", before_strategies.length);
//        console.log("test_delegateToBySignature_1 before_shares.length:", before_shares.length);
//
//        uint256 staker_priKey = getPrivateKeyByIndex(staker_index);
//        address temp_staker_addr = vm.addr(staker_priKey);
//        console.log("test_delegateToBySignature_1 temp_staker_addr:", temp_staker_addr);
//
//        uint256 delegation_prikey = getPrivateKeyByIndex(DELEGATION_APPROVER_index);
//        address temp_delegation_addr = vm.addr(delegation_prikey);
//        console.log("test_delegateToBySignature_1 temp_delegation_addr:", temp_delegation_addr);
//
//        uint256 approverExpiry = block.timestamp + 3600;
//        uint256 nonceBefore = delegationManager.stakerNonce(staker);
//
//        bytes32 structHash = keccak256(
//            abi.encode(delegationManager.STAKER_DELEGATION_TYPEHASH(), staker, operator, nonceBefore, approverExpiry)
//        );
//        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", delegationManager.domainSeparator(), structHash));
//
//        bytes memory signature;
//        {
//            (uint8 v, bytes32 r, bytes32 s) = vm.sign(staker_priKey, digestHash);
//            signature = abi.encodePacked(r, s, v);
//        }
//
//        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils.SignatureWithExpiry({
//            signature: signature,
//            expiry: approverExpiry
//        });
//        vm.startPrank(operator_address);
//        delegationManager.delegateToBySignature(staker, operator, signatureWithExpiry, signatureWithExpiry, bytes32(0));
//        vm.stopPrank();
//
//        address after_delegationApprover = delegationManager.operatorDetails(operator_address).delegationApprover;
//        console.log("test_delegateToBySignature_1 after_delegationApprover:", after_delegationApprover);
//
//        bool after_spent_flag = delegationManager.delegationApproverSaltIsSpent(before_delegationApprover, bytes32(0));
//        console.log("test_delegateToBySignature_1 after_spent_flag:", after_spent_flag);
//
//        address after_operator = delegationManager.delegatedTo(staker_address);
//        console.log("test_delegateToBySignature_1 after_operator:", after_operator);
//
//        (IStrategyBase[] memory after_strategies, uint256[] memory after_shares)
//        = delegationManager.getDelegatableShares(staker_address);
//        console.log("test_delegateToBySignature_1 after_strategies.length:", after_strategies.length);
//        console.log("test_delegateToBySignature_1 after_shares.length:", after_shares.length);
//    }

//    function test_undelegate_1() public {
//        console.log("====================================================");
//        console.log("============test_undelegate_1============");
//        console.log("====================================================");
//        address operator_address = operator;
//        address staker_address = staker;
//        console.log("test_undelegate_1 operator_address:", operator_address);
//        console.log("test_undelegate_1 staker_address:", staker_address);
//
//        _testDelegation(operator, staker, ethAmount, eigenAmount);
//
//        vm.startPrank();
//
//
//        vm.stopPrank();
//    }

    // need delegatedTo
//    function test_getOperatorShares() public {
//        console.log("====================================================");
//        console.log("==============test_getOperatorShares================");
//        console.log("====================================================");
//        address operator_address = operator;
//        address staker_address = staker;
//        console.log("test_getOperatorShares operator_address:", operator_address);
//        console.log("test_getOperatorShares staker_address:", staker_address);
//
//        console.log("test_getOperatorShares owner:", delegationManager.owner());
//
//        console.log("test_getOperatorShares delegationManager:", address(delegationManager));
//        _depositIntoStrategy();
//
//        vm.startPrank(staker_address);
//
//        IStrategyBase[] memory deployedStrategyArray = new IStrategyBase[](1);
//        for (uint256 i = 0; i < deployedStrategyArray.length; i++) {
//            deployedStrategyArray[i] = IStrategyBase(address(strategyBase1));
//        }
//
//        (uint256[] memory shares) = delegationManager.getOperatorShares(operator_address, deployedStrategyArray);
//
//        console.log("Number of strategies:", shares.length);
//        assertTrue(shares.length == 1, "shares.length == 1,");
//
//        for (uint256 i = 0; i < shares.length; i++) {
//            console.log("test_getOperatorShares Shares:", shares[i]);
//            assertTrue(shares[i] == 0, "shares[i] == 0");
//        }
//        vm.stopPrank();
//    }

//    need delegated to
//    function test_queueWithdrawals() public {
//        vm.startPrank();
//        delegationManager.queueWithdrawals();
//        vm.stopPrank();
//    }

//    need delegated to
//    function test_completeQueuedWithdrawal() public {
//        vm.startPrank();
//        vm.stopPrank();
//    }

//    need delegated to
//    function test_completeQueuedWithdrawals() public {
//        vm.startPrank();
//        delegationManager.completeQueuedWithdrawal();
//        vm.stopPrank();
//    }

    function test_migrateQueuedWithdrawals() public {
//        vm.startPrank();
//        delegationManager.migrateQueuedWithdrawals();
//        vm.stopPrank();
    }

//    need delegated to
//    function test_increaseDelegatedShares() public {
//        vm.startPrank();
//        delegationManager.increaseDelegatedShares();
//        vm.stopPrank();
//    }

//    need delegated to
//    function test_decreaseDelegatedShares() public {
//        console.log("====================================================");
//        console.log("========test_decreaseDelegatedShares============");
//        console.log("====================================================");
//        address operator_address = operator;
//        address staker_address = staker;
//        console.log("test_decreaseDelegatedShares operator_address:", operator_address);
//        console.log("test_decreaseDelegatedShares staker_address:", staker_address);
//
//        vm.startPrank(staker_address);
//
//        StrategyBase[] memory deployedStrategyArrayMemory = new StrategyBase[](1);
//        deployedStrategyArrayMemory[0] = strategyBase1;
//
//        uint256[] memory withdrawalDelayBlocksMemory = new uint256[](1);
//        withdrawalDelayBlocksMemory[0] = 7200;
//
//        IStrategyBase[] memory deployedStrategyArray = new IStrategyBase[](deployedStrategyArrayMemory.length);
//        for (uint256 i = 0; i < deployedStrategyArrayMemory.length; i++) {
//            deployedStrategyArray[i] = IStrategyBase(address(deployedStrategyArrayMemory[i]));
//        }
//
//        vm.stopPrank();
//    }

    function test_setMinWithdrawalDelayBlocks() public {
        console.log("====================================================");
        console.log("========test_setMinWithdrawalDelayBlocks============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        console.log("test_setMinWithdrawalDelayBlocks operator_address:", operator_address);
        console.log("test_setMinWithdrawalDelayBlocks staker_address:", staker_address);


        console.log("test_setMinWithdrawalDelayBlocks owner:", delegationManager.owner());

        vm.startPrank(staker_address);

        delegationManager.setMinWithdrawalDelayBlocks(7200);

        uint256 temp = delegationManager.minWithdrawalDelayBlocks();
        console.log("test_setMinWithdrawalDelayBlocks temp:", temp);
        assertTrue(temp == 7200, "temp == 7200");

        vm.stopPrank();
    }

    function test_setStrategyWithdrawalDelayBlocks() public {
        console.log("====================================================");
        console.log("========test_setStrategyWithdrawalDelayBlocks============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        console.log("test_setStrategyWithdrawalDelayBlocks operator_address:", operator_address);
        console.log("test_setStrategyWithdrawalDelayBlocks staker_address:", staker_address);


        console.log("test_setStrategyWithdrawalDelayBlocks owner:", delegationManager.owner());

        vm.startPrank(staker_address);

        StrategyBase[] memory deployedStrategyArrayMemory = new StrategyBase[](1);
        deployedStrategyArrayMemory[0] = strategyBase1;

        uint256[] memory withdrawalDelayBlocksMemory = new uint256[](1);
        withdrawalDelayBlocksMemory[0] = 7200;

        IStrategyBase[] memory deployedStrategyArray = new IStrategyBase[](deployedStrategyArrayMemory.length);
        for (uint256 i = 0; i < deployedStrategyArrayMemory.length; i++) {
            deployedStrategyArray[i] = IStrategyBase(address(deployedStrategyArrayMemory[i]));
        }

        uint256 before_withdrawalDelayBlocks = delegationManager.strategyWithdrawalDelayBlocks(strategyBase1);
        console.log("test_setStrategyWithdrawalDelayBlocks before_withdrawalDelayBlocks:", before_withdrawalDelayBlocks);

        delegationManager.setStrategyWithdrawalDelayBlocks(deployedStrategyArray, withdrawalDelayBlocksMemory);

        uint256 after_withdrawalDelayBlocks = delegationManager.strategyWithdrawalDelayBlocks(strategyBase1);
        console.log("test_setStrategyWithdrawalDelayBlocks after_withdrawalDelayBlocks:", after_withdrawalDelayBlocks);

        assertTrue(after_withdrawalDelayBlocks == 7200, "after_withdrawalDelayBlocks == 7200");

        vm.stopPrank();
    }

    function test_getDelegatableShares() public {
        console.log("====================================================");
        console.log("========test_getDelegatableShares============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        console.log("test_getDelegatableShares operator_address:", operator_address);
        console.log("test_getDelegatableShares staker_address:", staker_address);

        console.log("test_getDelegatableShares owner:", delegationManager.owner());

        console.log("test_getDelegatableShares delegationManager:", address(delegationManager));
        _depositIntoStrategy();

        vm.startPrank(staker_address);

        (IStrategyBase[] memory strategies, uint256[] memory shares) = delegationManager.getDelegatableShares(staker_address);

        console.log("Number of strategies:", strategies.length);
        assertTrue(strategies.length == 1, "strategies.length == 1,");

        for (uint256 i = 0; i < strategies.length; i++) {
            console.log("Strategy address:", address(strategies[i]));
            assertTrue(address(strategies[i]) == address(strategyBase1), "address(strategies[i]) == address(strategyBase1)");
            console.log("Shares:", shares[i]);
            assertTrue(shares[i] == 1e18, "shares[i] == 1e18");
        }
        vm.stopPrank();
    }

    function test_getWithdrawalDelay() public {
        console.log("====================================================");
        console.log("========test_getDelegatableShares============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        console.log("test_getDelegatableShares operator_address:", operator_address);
        console.log("test_getDelegatableShares staker_address:", staker_address);

        console.log("test_getDelegatableShares owner:", delegationManager.owner());

        StrategyBase[] memory deployedStrategyArrayMemory = new StrategyBase[](1);
        deployedStrategyArrayMemory[0] = strategyBase1;

        IStrategyBase[] memory deployedStrategyArray = new IStrategyBase[](deployedStrategyArrayMemory.length);
        for (uint256 i = 0; i < deployedStrategyArrayMemory.length; i++) {
            deployedStrategyArray[i] = IStrategyBase(address(deployedStrategyArrayMemory[i]));
        }

        // delegationManagerProxyAdmin.upgradeAndCall(  initialize
        // DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS = 50400;
        uint256 aa = delegationManager.getWithdrawalDelay(deployedStrategyArray);
        console.log("test_getDelegatableShares aa:", aa);
        assertTrue(aa == 50400, "aa == 50400");
    }

    function test_calculateWithdrawalRoot() public {
        console.log("====================================================");
        console.log("========test_calculateWithdrawalRoot============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        console.log("test_calculateWithdrawalRoot operator_address:", operator_address);
        console.log("test_calculateWithdrawalRoot staker_address:", staker_address);

        _depositIntoStrategy();

        StrategyBase[] memory deployedStrategyArrayMemory = new StrategyBase[](1);
        deployedStrategyArrayMemory[0] = strategyBase1;

        (IStrategyBase[] memory strategies, uint256[] memory shares) = delegationManager.getDelegatableShares(staker_address);

        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: staker_address,
            delegatedTo: operator_address,
            withdrawer: staker_address,
            nonce: 1,
            startBlock: 100,
            strategies: strategies,
            shares: shares
        });

        bytes32 withdrawalRoot = delegationManager.calculateWithdrawalRoot(withdrawal);
        console.log("test_calculateWithdrawalRoot withdrawalRoot:");
        console.logBytes32(withdrawalRoot);
        assertTrue(withdrawalRoot == 0xd2c961f36827ab5dc3ccd72dd10e9a92ab6f8f087037436c370e8f0b61b0bf2a, "test_calculateWithdrawalRoot");
    }

    function test_calculateCurrentStakerDelegationDigestHash() public {
        console.log("====================================================");
        console.log("========test_calculateCurrentStakerDelegationDigestHash============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        console.log("test_calculateCurrentStakerDelegationDigestHash operator_address:", operator_address);
        console.log("test_calculateCurrentStakerDelegationDigestHash staker_address:", staker_address);

        bytes32 digestHash = delegationManager.calculateCurrentStakerDelegationDigestHash(staker_address, operator_address, 100);
        console.log("test_calculateCurrentStakerDelegationDigestHash digestHash:");
        console.logBytes32(digestHash);
        assertTrue(digestHash == 0x5b7534e1342518bcb708928af08cf3c81ed5f9a767c0bcf1213b73f6ea98a1c5, "test_calculateCurrentStakerDelegationDigestHash");
    }

    function test_calculateStakerDelegationDigestHash() public {
        console.log("====================================================");
        console.log("========test_calculateStakerDelegationDigestHash============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        console.log("test_calculateStakerDelegationDigestHash operator_address:", operator_address);
        console.log("test_calculateStakerDelegationDigestHash staker_address:", staker_address);

        bytes32 digestHash = delegationManager.calculateStakerDelegationDigestHash(staker_address, 1, operator_address, 100);
        console.log("test_calculateStakerDelegationDigestHash digestHash:");
        console.logBytes32(digestHash);
        assertTrue(digestHash == 0x8bb99bbab40700284a122e280a494479f01f310f2d66d69730de365722a7f094, "test_calculateStakerDelegationDigestHash");
    }

    function test_calculateDelegationApprovalDigestHash() public {
        console.log("====================================================");
        console.log("========test_calculateStakerDelegationDigestHash============");
        console.log("====================================================");
        address operator_address = operator;
        address staker_address = staker;
        console.log("test_calculateStakerDelegationDigestHash operator_address:", operator_address);
        console.log("test_calculateStakerDelegationDigestHash staker_address:", staker_address);
        bytes32 digestHash = delegationManager.calculateDelegationApprovalDigestHash(staker, operator, operator_address, emptySalt, 1);
        console.log("test_calculateStakerDelegationDigestHash digestHash:");
        console.logBytes32(digestHash);
        assertEq(digestHash, 0x394590baa13c0c8bb0b38c0640fbda16e4df78613a34147bd56f45b34a86684e, "test_calculateDelegationApprovalDigestHash");
    }
}

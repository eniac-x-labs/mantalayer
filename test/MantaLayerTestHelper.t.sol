// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../test/MantaLayerDeployer.t.sol";
import "@/contracts/interfaces/ISignatureUtils.sol";

contract MantaLayerTestHelper is MantaLayerDeployer {
    uint8 durationToInit = 2;
    uint256 public SECP256K1N_MODULUS = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    uint256 public SECP256K1N_MODULUS_HALF = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    uint256[] sharesBefore;
    uint256[] balanceBefore;
    uint256[] priorTotalShares;
    uint256[] strategyTokenBalance;

    /**
     * @notice Helper function to test `initiateDelegation` functionality.  Handles registering as an operator, depositing tokens
     * into both WMANTA strategy, as well as delegating assets from "stakers" to the operator.
     * @param operatorIndex is the index of the operator to use from the test-data/operators.json file
     * @param amountMantaToDeposit amount of Manta token to deposit
     */

    function _testInitiateDelegation(
        uint8 operatorIndex,
        uint256 amountMantaToDeposit
    ) public returns (uint256 amountMantaStaked) {
        address operator = getOperatorAddress(operatorIndex);

        //setting up operator's delegationManager terms
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            earningsReceiver: operator,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });
        _testRegisterAsOperator(operator, operatorDetails);

        for (uint256 i; i < stakers.length; i++) {
            //initialize wmanta balance for staker
            wmanta.transfer(stakers[i], amountMantaToDeposit);

            //deposit staker's wmanta into strategy manager
            _testDepositManta(stakers[i], amountMantaToDeposit);

            //delegate the staker's deposits to operator
            uint256 operatorMantaSharesBefore = delegationManager.operatorShares(operator, wmantaStrat);
            _testDelegateToOperator(stakers[i], operator);
            //verify that `increaseOperatorShares` worked
            assertTrue(
                delegationManager.operatorShares(operator, wmantaStrat) - operatorMantaSharesBefore == amountMantaToDeposit
            );
        }
        amountMantaStaked += delegationManager.operatorShares(operator, wmantaStrat);

        return amountMantaStaked;
    }

    /**
     * @notice Register 'sender' as an operator, setting their 'OperatorDetails' in DelegationManager to 'operatorDetails', verifies
     * that the storage of DelegationManager contract is updated appropriately
     *
     * @param sender is the address being registered as an operator
     * @param operatorDetails is the `sender`'s OperatorDetails struct
     */
    function _testRegisterAsOperator(
        address sender,
        IDelegationManager.OperatorDetails memory operatorDetails
    ) internal {
        vm.startPrank(sender);
        string memory emptyStringForMetadataURI;
        delegationManager.registerAsOperator(operatorDetails, emptyStringForMetadataURI);
        assertTrue(delegationManager.isOperator(sender), "testRegisterAsOperator: sender is not a operator");

        assertTrue(
            keccak256(abi.encode(delegationManager.operatorDetails(sender))) == keccak256(abi.encode(operatorDetails)),
            "_testRegisterAsOperator: operatorDetails not set appropriately"
        );

        assertTrue(delegationManager.isDelegated(sender), "_testRegisterAsOperator: sender not marked as actively delegated");
        vm.stopPrank();
    }

    /**
     * @notice Deposits `amountToDeposit` of MANTA from address `sender` into `wmantaStrat`.
     * @param sender The address to spoof calls from using `vm.startPrank(sender)`
     * @param amountToDeposit Amount of MANTA that is first *transferred from this contract to `sender`* and then deposited by `sender` into `stratToDepositTo`
     */
    function _testDepositManta(address sender, uint256 amountToDeposit) internal returns (uint256 amountDeposited) {
        vm.assume(amountToDeposit <= MantaTotalSupply);
        amountDeposited = _testDepositToStrategy(sender, amountToDeposit, wmanta, wmantaStrat);
    }

    /**
     * @notice Deposits `amountToDeposit` of `underlyingToken` from address `sender` into `stratToDepositTo`.
     * *If*  `sender` has zero shares prior to deposit, *then* checks that `stratToDepositTo` is correctly added to their `stakerStrategyList` array.
     *
     * @param sender The address to spoof calls from using `vm.startPrank(sender)`
     * @param amountToDeposit Amount of token that is first *transferred from this contract to `sender`* and then deposited by `sender` into `stratToDepositTo`
     */
    function _testDepositToStrategy(
        address sender,
        uint256 amountToDeposit,
        IERC20 underlyingToken,
        IStrategyBase stratToDepositTo
    ) internal returns (uint256 amountDeposited) {
        // deposits will revert when amountToDeposit is 0
        vm.assume(amountToDeposit > 0);

        // whitelist the strategy for deposit, in case it wasn't before
        {
            vm.startPrank(strategyManager.strategyWhitelister());
            IStrategyBase[] memory _strategy = new IStrategyBase[](1);
            bool[] memory _thirdPartyTransfersForbiddenValues = new bool[](1);
            _strategy[0] = stratToDepositTo;
            strategyManager.addStrategiesToDepositWhitelist(_strategy, _thirdPartyTransfersForbiddenValues);
            vm.stopPrank();
        }

        uint256 operatorSharesBefore = strategyManager.stakerStrategyShares(sender, stratToDepositTo);
        // assumes this contract already has the underlying token!
        uint256 contractBalance = underlyingToken.balanceOf(address(this));
        // check the expected output
        uint256 expectedSharesOut = stratToDepositTo.underlyingToShares(amountToDeposit);
        // logging and error for misusing this function (see assumption above)
        if (amountToDeposit > contractBalance) {
            emit log("amountToDeposit > contractBalance");
            emit log_named_uint("amountToDeposit is", amountToDeposit);
            emit log_named_uint("while contractBalance is", contractBalance);
            revert("_testDepositToStrategy failure");
        } else {
            underlyingToken.transfer(sender, amountToDeposit);
            vm.startPrank(sender);
            underlyingToken.approve(address(strategyManager), type(uint256).max);
            strategyManager.depositIntoStrategy(stratToDepositTo, underlyingToken, amountToDeposit);
            amountDeposited = amountToDeposit;

            //check if depositor has never used this strat, that it is added correctly to stakerStrategyList array.
            if (operatorSharesBefore == 0) {
                // check that strategy is appropriately added to dynamic array of all of sender's strategies
                assertTrue(
                    strategyManager.stakerStrategyList(sender, strategyManager.stakerStrategyListLength(sender) - 1) ==
                        stratToDepositTo,
                    "_testDepositToStrategy: stakerStrategyList array updated incorrectly"
                );
            }

            // check that the shares out match the expected amount out
            assertEq(
                strategyManager.stakerStrategyShares(sender, stratToDepositTo) - operatorSharesBefore,
                expectedSharesOut,
                "_testDepositToStrategy: actual shares out should match expected shares out"
            );
        }
        vm.stopPrank();
    }

    /**
     * @notice tries to delegate from 'staker' to 'operator', verifies that staker has at least some shares
     * delegatedShares update correctly for 'operator' and delegated status is updated correctly for 'staker'
     * @param staker the staker address to delegate from
     * @param operator the operator address to delegate to
     */
    function _testDelegateToOperator(address staker, address operator) internal {
        //staker-specific information
        (IStrategyBase[] memory delegateStrategies, uint256[] memory delegateShares) = strategyManager.getDeposits(staker);

        uint256 numStrats = delegateShares.length;
        assertTrue(numStrats != 0, "_testDelegateToOperator: delegating from address with no deposits");
        uint256[] memory inititalSharesInStrats = new uint256[](numStrats);
        for (uint256 i = 0; i < numStrats; ++i) {
            inititalSharesInStrats[i] = delegationManager.operatorShares(operator, delegateStrategies[i]);
        }

        vm.startPrank(staker);
        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry;
        delegationManager.delegateTo(operator, signatureWithExpiry, bytes32(0));
        vm.stopPrank();

        assertTrue(
            delegationManager.delegatedTo(staker) == operator,
            "_testDelegateToOperator: delegated address not set appropriately"
        );
        assertTrue(delegationManager.isDelegated(staker), "_testDelegateToOperator: delegated status not set appropriately");

        for (uint256 i = 0; i < numStrats; ++i) {
            uint256 operatorSharesBefore = inititalSharesInStrats[i];
            uint256 operatorSharesAfter = delegationManager.operatorShares(operator, delegateStrategies[i]);
            assertTrue(
                operatorSharesAfter == (operatorSharesBefore + delegateShares[i]),
                "_testDelegateToOperator: delegatedShares not increased correctly"
            );
        }
    }

    /**
     * @notice deploys 'numStratsToAdd' strategies contracts and initializes them to treat `underlyingToken` as their underlying token
     * and then deposits 'amountToDeposit' to each of them from 'sender'
     *
     * @param sender address that is depositing into the strategies
     * @param amountToDeposit amount being deposited
     * @param numStratsToAdd number of strategies that are being deployed and deposited into
     */
    function _testDepositStrategies(address sender, uint256 amountToDeposit, uint8 numStratsToAdd) internal {
        // hard-coded input
        IERC20 underlyingToken = wmanta;
        vm.assume(numStratsToAdd > 0 && numStratsToAdd <= 20);
        IStrategyBase[] memory stratsToDepositTo = new IStrategyBase[](numStratsToAdd);
        StrategyBase strategyBaseImplementation = new StrategyBase(strategyManager);
        for (uint8 i = 0; i < numStratsToAdd; ++i) {
            TransparentUpgradeableProxy strategyBaseProxyInstance = new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
            StrategyBase strategy = StrategyBase(address(strategyBaseProxyInstance));
            ProxyAdmin strategyBaseProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(strategyBaseProxyInstance)));
            strategyBaseProxyAdmin.upgradeAndCall(
                ITransparentUpgradeableProxy(payable(address(strategy))),
                address(strategyBaseImplementation),
                abi.encodeWithSelector(
                    StrategyBase.initialize.selector,
                    underlyingToken,
                    mantaLayerPauserReg,
                    STRATEGY_MAX_PER_DEPOSIT,
                    STRATEGY_MAX_TOTAL_DEPOSITS
                )
            );
            stratsToDepositTo[i] = strategy;
            _testDepositToStrategy(sender, amountToDeposit, underlyingToken, StrategyBase(address(stratsToDepositTo[i])));
        }
        for (uint8 i = 0; i < numStratsToAdd; ++i) {
            // check that strategy is appropriately added to dynamic array of all of sender's strategies
            assertTrue(
                strategyManager.stakerStrategyList(sender, i) == stratsToDepositTo[i],
                "stakerStrategyList array updated incorrectly"
            );

            // TODO: perhaps remove this is we can. seems brittle if we don't track the number of strategies somewhere
            //store strategy in mapping of strategies
            strategies[i] = IStrategyBase(address(stratsToDepositTo[i]));
        }
    }

    /**
     * @notice Creates a queued withdrawal from `staker`. Begins by registering the staker as a delegate (if specified), then deposits `amountToDeposit`
     * into the WMANTA strategy, and then queues a withdrawal using `strategyManager.queueWithdrawal`.
     * @notice After initiating a queued withdrawal, this test checks that `strategyManager.canCompleteQueuedWithdrawal` immediately returns the correct
     * response depending on whether `staker` is delegated or not.
     */
    function _createQueuedWithdrawal(
        address staker,
        bool registerAsOperator,
        uint256 amountToDeposit,
        IStrategyBase[] memory strategyArray,
        uint256[] memory shareAmounts,
        uint256[] memory _strategyIndexes,
        address withdrawer
    ) internal returns (bytes32 withdrawalRoot, IDelegationManager.Withdrawal memory queuedWithdrawal) {
        require(amountToDeposit >= shareAmounts[0], "_createQueuedWithdrawal: sanity check failed");
        // we do this here to ensure that `staker` is delegated if `registerAsOperator` is true
        if (registerAsOperator) {
            assertTrue(!delegationManager.isDelegated(staker), "_createQueuedWithdrawal: staker is already delegated");
            IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
                earningsReceiver: staker,
                delegationApprover: address(0),
                stakerOptOutWindowBlocks: 0
            });
            _testRegisterAsOperator(staker, operatorDetails);
            assertTrue(
                delegationManager.isDelegated(staker),
                "_createQueuedWithdrawal: staker isn't delegated when they should be"
            );
        }

        queuedWithdrawal = IDelegationManager.Withdrawal({
            strategies: strategyArray,
            shares: shareAmounts,
            staker: staker,
            withdrawer: withdrawer,
            nonce: delegationManager.cumulativeWithdrawalsQueued(staker),
            delegatedTo: delegationManager.delegatedTo(staker),
            startBlock: uint32(block.number)
        });

        {
            //make deposit in WMANTA strategy
            uint256 amountDeposited = _testDepositManta(staker, amountToDeposit);
            // We can't withdraw more than we deposit
            if (shareAmounts[0] > amountDeposited) {
                vm.expectRevert("StrategyManager._removeShares: shareAmount too high");
            }
        }

        //queue the withdrawal
        withdrawalRoot = _testQueueWithdrawal(staker, _strategyIndexes, strategyArray, shareAmounts, withdrawer);
        return (withdrawalRoot, queuedWithdrawal);
    }

    /**
     * Helper for ECDSA signatures: combines V and S into VS - if S is greater than SECP256K1N_MODULUS_HALF, then we
     * get the modulus, so that the leading bit of s is always 0.  Then we set the leading
     * bit to be either 0 or 1 based on the value of v, which is either 27 or 28
     */
    function getVSfromVandS(uint8 v, bytes32 s) internal view returns (bytes32) {
        if (uint256(s) > SECP256K1N_MODULUS_HALF) {
            s = bytes32(SECP256K1N_MODULUS - uint256(s));
        }

        bytes32 vs = s;
        if (v == 28) {
            vs = bytes32(uint256(s) ^ (1 << 255));
        }

        return vs;
    }

    /// @notice registers a fixed address as an operator, delegates to it from a second address,
    ///         and checks that the operator's voteWeights increase properly
    /// @param operator is the operator being delegated to.
    /// @param staker is the staker delegating stake to the operator.
    /// @param mantaAmount is the amount of MANTA to deposit into the operator's strategy.
    function _testDelegation(
        address operator,
        address staker,
        uint256 mantaAmount
    ) internal {
        if (!delegationManager.isOperator(operator)) {
            IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
                earningsReceiver: operator,
                delegationApprover: address(0),
                stakerOptOutWindowBlocks: 0
            });
            _testRegisterAsOperator(operator, operatorDetails);
        }

        uint256 amountBefore = delegationManager.operatorShares(operator, wmantaStrat);

        //making additional deposits to the strategies
        assertTrue(!delegationManager.isDelegated(staker) == true, "testDelegation: staker is not delegate");
        _testDepositManta(staker, mantaAmount);
        _testDelegateToOperator(staker, operator);
        assertTrue(delegationManager.isDelegated(staker) == true, "testDelegation: staker is not delegate");

        (/*IStrategyBase[] memory updatedStrategies*/, uint256[] memory updatedShares) = strategyManager.getDeposits(staker);

        IStrategyBase _strat = wmantaStrat;
        // IStrategyBase _strat = strategyManager.stakerStrategyList(staker, 0);
        assertTrue(address(_strat) != address(0), "stakerStrategyList not updated correctly");

        assertTrue(
            delegationManager.operatorShares(operator, _strat) - updatedShares[0] == amountBefore,
            "ETH operatorShares not updated correctly"
        );
    }

    /**
     * @notice Helper function to complete an existing queued withdrawal in shares
     */
    function _testCompleteQueuedWithdrawalShares(
        address depositor,
        IStrategyBase[] memory strategyArray,
        IERC20 token,
        uint256[] memory shareAmounts,
        address delegatedTo,
        address withdrawer,
        uint256 nonce,
        uint32 withdrawalStartBlock
    ) internal {
        vm.startPrank(withdrawer);

        for (uint256 i = 0; i < strategyArray.length; i++) {
            sharesBefore.push(strategyManager.stakerStrategyShares(withdrawer, strategyArray[i]));
        }
        IDelegationManager.Withdrawal memory queuedWithdrawal = IDelegationManager.Withdrawal({
            strategies: strategyArray,
            shares: shareAmounts,
            staker: depositor,
            withdrawer: withdrawer,
            nonce: nonce,
            startBlock: withdrawalStartBlock,
            delegatedTo: delegatedTo
        });

        // complete the queued withdrawal
        delegationManager.completeQueuedWithdrawal(queuedWithdrawal, token);

        for (uint256 i = 0; i < strategyArray.length; i++) {
            require(
                strategyManager.stakerStrategyShares(withdrawer, strategyArray[i]) == sharesBefore[i] + shareAmounts[i],
                "_testCompleteQueuedWithdrawalShares: withdrawer shares not incremented"
            );
        }
        vm.stopPrank();
    }

    /**
     * @notice Helper function to complete an existing queued withdrawal in tokens
     */
    function _testCompleteQueuedWithdrawalTokens(
        address depositor,
        IStrategyBase[] memory strategyArray,
        IERC20 token,
        uint256[] memory shareAmounts,
        address delegatedTo,
        address withdrawer,
        uint256 nonce,
        uint32 withdrawalStartBlock
    ) internal {
        vm.startPrank(withdrawer);

        for (uint256 i = 0; i < strategyArray.length; i++) {
            balanceBefore.push(strategyArray[i].underlyingToken().balanceOf(withdrawer));
            priorTotalShares.push(strategyArray[i].totalShares());
            strategyTokenBalance.push(strategyArray[i].underlyingToken().balanceOf(address(strategyArray[i])));
        }

        IDelegationManager.Withdrawal memory queuedWithdrawal = IDelegationManager.Withdrawal({
            strategies: strategyArray,
            shares: shareAmounts,
            staker: depositor,
            withdrawer: withdrawer,
            nonce: nonce,
            startBlock: withdrawalStartBlock,
            delegatedTo: delegatedTo
        });
        // complete the queued withdrawal
        delegationManager.completeQueuedWithdrawal(queuedWithdrawal, token);

        for (uint256 i = 0; i < strategyArray.length; i++) {
            //uint256 strategyTokenBalance = strategyArray[i].underlyingToken().balanceOf(address(strategyArray[i]));
            uint256 tokenBalanceDelta = (strategyTokenBalance[i] * shareAmounts[i]) / priorTotalShares[i];

            // filter out unrealistic case, where the withdrawer is the strategy contract itself
            vm.assume(withdrawer != address(strategyArray[i]));
            require(
                strategyArray[i].underlyingToken().balanceOf(withdrawer) == balanceBefore[i] + tokenBalanceDelta,
                "_testCompleteQueuedWithdrawalTokens: withdrawer balance not incremented"
            );
        }
        vm.stopPrank();
    }

    function _testQueueWithdrawal(
        address depositor,
        uint256[] memory /*strategyIndexes*/,
        IStrategyBase[] memory strategyArray,
        uint256[] memory shareAmounts,
        address withdrawer
    ) internal returns (bytes32) {
        vm.startPrank(depositor);

        IDelegationManager.QueuedWithdrawalParams[] memory params = new IDelegationManager.QueuedWithdrawalParams[](1);

        params[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: strategyArray,
            shares: shareAmounts,
            withdrawer: withdrawer
        });

        bytes32[] memory withdrawalRoots = new bytes32[](1);
        withdrawalRoots = delegationManager.queueWithdrawals(params);
        vm.stopPrank();
        return withdrawalRoots[0];
    }
}

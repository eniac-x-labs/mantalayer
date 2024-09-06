// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "forge-std/console.sol";
import "forge-std/Test.sol";

import "@/access/PauserRegistry.sol";
import "@/contracts/core/StrategyBase.sol";
import "@/contracts/core/StrategyManager.sol";
import "@/contracts/core/DelegationManager.sol";
import "@/contracts/core/RewardManager.sol";

import "@test/script/utils/EmptyContract.sol";
import "@test/script/utils/ExistingDeploymentParserTest.t.sol";

contract DeployerBasicTest is ExistingDeploymentParserTest {

//    function run() external virtual {
//        _parseInitialDeploymentParams();
//
//        // START RECORDING TRANSACTIONS FOR DEPLOYMENT
//        vm.startBroadcast();
//
//        emit log_named_address("Deployer Address", msg.sender);
//
//        _deployFromScratch();
//
//        // STOP RECORDING TRANSACTIONS FOR DEPLOYMENT
//        vm.stopBroadcast();
//
//        // Sanity Checks
//        _verifyContractPointers();
//        _verifyImplementations();
//        _verifyContractsInitialized({isInitialDeployment: true});
//        _verifyInitializationParams();
//
//        logAndOutputContractAddresses("test/script/output/DeploymentBasic.config.json");
//    }

    /**
        * @notice Deploy MantaLayer contracts from scratch for Manta Network
     */
    function _deployFromScratch() internal {
        vm.startPrank(staker);
        console.log("_deployFromScratch address(this) ", address(this));
        console.log("_deployFromScratch msg.sender ", address(msg.sender));

        // Deploy ProxyAdmin, later set admins for all proxies to be executorMultisig
        mantaLayerProxyAdmin = new ProxyAdmin(executorMultisig);
        console.log("_deployFromScratch mantaLayerProxyAdmin = ", address(mantaLayerProxyAdmin));

        // Set multisigs as pausers, executorMultisig as unpauser
        address[] memory pausers = new address[](3);
        pausers[0] = executorMultisig;
        pausers[1] = operationsMultisig;
        pausers[2] = pauserMultisig;
        address unpauser = executorMultisig;
        mantaLayerPauserReg = new PauserRegistry(pausers, unpauser);

        console.log("_deployFromScratch executorMultisig ", address(executorMultisig));
        console.log("_deployFromScratch operationsMultisig ", address(operationsMultisig));
        console.log("_deployFromScratch pauserMultisig ", address(pauserMultisig));
        console.log("_deployFromScratch unpauser ", address(unpauser));
        console.log("_deployFromScratch mantaLayerPauserReg ", address(mantaLayerPauserReg));

        /**
         * Deploy upgradeable proxy contracts that **will point** to the implementations. Since the implementation contracts are
         * not yet deployed, we give these proxies an empty contract as the initial implementation, to act as if they have no code.
         */
        emptyContract = new EmptyContract();
        TransparentUpgradeableProxy delegationManagerProxyInstance = new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
        delegationManager = DelegationManager(address(delegationManagerProxyInstance));
        delegationManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(delegationManagerProxyInstance)));
        console.log("_deployFromScratch delegationManagerProxyInstance ", address(delegationManagerProxyInstance));
        console.log("_deployFromScratch delegationManagerProxyAdmin ", address(delegationManagerProxyAdmin));
        console.log("_deployFromScratch delegationManager ", address(delegationManager));

        TransparentUpgradeableProxy strategyManagerProxyInstance = new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
        strategyManager = StrategyManager(address(strategyManagerProxyInstance));
        strategyManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(strategyManagerProxyInstance)));
        console.log("_deployFromScratch strategyManagerProxyInstance ", address(strategyManagerProxyInstance));
        console.log("_deployFromScratch strategyManagerProxyAdmin ", address(strategyManagerProxyAdmin));
        console.log("_deployFromScratch strategyManager ", address(strategyManager));

        delegationManagerImplementation = new DelegationManager(strategyManager);
        strategyManagerImplementation = new StrategyManager(delegationManager);
        console.log("_deployFromScratch DelegationManager delegationManagerImplementation ", address(delegationManagerImplementation));
        console.log("_deployFromScratch StrategyManager strategyManagerImplementation ", address(strategyManagerImplementation));

        // Upgrade the proxy contracts to point to the implementations
        IStrategyBase[] memory initializeStrategiesToSetDelayBlocks = new IStrategyBase[](0);
        uint256[] memory initializeWithdrawalDelayBlocks = new uint256[](0);

        console.log("_deployFromScratch DELEGATION_MANAGER_INIT_PAUSED_STATUS ", DELEGATION_MANAGER_INIT_PAUSED_STATUS);
        console.log("_deployFromScratch DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS ", DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS);

        // DelegationManager
        console.log("_deployFromScratch delegationManagerImplementation owner ", delegationManagerImplementation.owner());
        console.log("_deployFromScratch delegationManagerProxyAdmin owner ", delegationManagerProxyAdmin.owner());

        console.log("_deployFromScratch delegationManagerProxyAdmin.upgradeAndCall msg.sender ", msg.sender);

        delegationManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(delegationManager))),
            address(delegationManagerImplementation),
            abi.encodeWithSelector(
                DelegationManager.initialize.selector,
                executorMultisig, // initialOwner
                mantaLayerPauserReg,
                DELEGATION_MANAGER_INIT_PAUSED_STATUS,
                DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS,
                initializeStrategiesToSetDelayBlocks,
                initializeWithdrawalDelayBlocks
            )
        );

        console.log("_deployFromScratch mantaLayerPauserReg ", address(mantaLayerPauserReg));
        console.log("_deployFromScratch STRATEGY_MANAGER_INIT_PAUSED_STATUS ", STRATEGY_MANAGER_INIT_PAUSED_STATUS);

        console.log("_deployFromScratch strategyManagerProxyAdmin.upgradeAndCall msg.sender ", address(msg.sender));
        // StrategyManager
        strategyManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(strategyManager))),
            address(strategyManagerImplementation),
            abi.encodeWithSelector(
                StrategyManager.initialize.selector,
                staker, //initialOwner, set to executorMultisig later after whitelisting strategies
                staker, //initial whitelister, set to STRATEGY_MANAGER_WHITELISTER later
                mantaLayerPauserReg,
                STRATEGY_MANAGER_INIT_PAUSED_STATUS
            )
        );

        console.log("_deployFromScratch strategyManager ", address(strategyManager));
        // Deploy Strategies
        baseStrategyImplementation = new StrategyBase(strategyManager);
        console.log("_deployFromScratch baseStrategyImplementation ", address(baseStrategyImplementation));
        // whitelist params
        IStrategyBase[] memory strategiesToWhitelist = new IStrategyBase[](numStrategiesToDeploy);
        bool[] memory thirdPartyTransfersForbiddenValues = new bool[](numStrategiesToDeploy);

        for (uint256 i = 0; i < numStrategiesToDeploy; i++) {
            StrategyUnderlyingTokenConfig memory strategyConfig = strategiesToDeploy[i];
            console.log("_deployFromScratch strategyConfig tokenAddress ", strategyConfig.tokenAddress);
            console.log("_deployFromScratch strategyConfig tokenName ", strategyConfig.tokenName);
            console.log("_deployFromScratch strategyConfig tokenSymbol ", strategyConfig.tokenSymbol);

            // Deploy and upgrade strategy
            TransparentUpgradeableProxy strategyBaseProxyInstance = new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
            StrategyBase strategy = StrategyBase(address(strategyBaseProxyInstance));
            console.log("_deployFromScratch strategyConfig strategy ", address(strategy));
            strategyBaseProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(strategyBaseProxyInstance)));
            console.log("_deployFromScratch strategyConfig strategyBaseProxyAdmin ", address(strategyBaseProxyAdmin));

            console.log("DeployerBasic strategyConfig STRATEGY_MAX_PER_DEPOSIT ", STRATEGY_MAX_PER_DEPOSIT);
            console.log("DeployerBasic strategyConfig STRATEGY_MAX_TOTAL_DEPOSITS ", STRATEGY_MAX_TOTAL_DEPOSITS);
            strategyBaseProxyAdmin.upgradeAndCall(
                ITransparentUpgradeableProxy(payable(address(strategy))),
                address(baseStrategyImplementation),
                abi.encodeWithSelector(
                    StrategyBase.initialize.selector,
                    IERC20(strategyConfig.tokenAddress),
                    mantaLayerPauserReg,
                    STRATEGY_MAX_PER_DEPOSIT,
                    STRATEGY_MAX_TOTAL_DEPOSITS
                )
            );

            strategiesToWhitelist[i] = strategy;
            thirdPartyTransfersForbiddenValues[i] = false;
            strategyBase1 = strategy;
            deployedStrategyArray.push(strategy);
        }
        for (uint256 i = 0; i < strategiesToWhitelist.length; ++i) {
            console.log("DeployerBasic strategyConfig strategiesToWhitelist ", address(strategiesToWhitelist[i]));
        }
        for (uint256 i = 0; i < thirdPartyTransfersForbiddenValues.length; ++i) {
            console.log("DeployerBasic strategyConfig thirdPartyTransfersForbiddenValues ", thirdPartyTransfersForbiddenValues[i]);
        }
        for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
            console.log("DeployerBasic strategyConfig deployedStrategyArray ", address(deployedStrategyArray[i]));
        }

        console.log("DeployerBasic strategyConfig REWARD_MANAGER_RWARD_TOKEN_ADDRESS ", REWARD_MANAGER_RWARD_TOKEN_ADDRESS);
        console.log("DeployerBasic strategyConfig REWARD_MANAGER_STAKE_PERCENTAGE ", REWARD_MANAGER_STAKE_PERCENTAGE);
        // Deploy RewardManager proxy and implementation
        rewardManagerImplementation = new RewardManager(
            delegationManager,
            strategyManager,
            IERC20(REWARD_MANAGER_RWARD_TOKEN_ADDRESS)
        );

        console.log("DeployerBasic strategyConfig rewardManagerImplementation ", address(rewardManagerImplementation));
        console.log("DeployerBasic strategyConfig mantaLayerProxyAdmin ", address(mantaLayerProxyAdmin));
        rewardManager = RewardManager(
            address(
                new TransparentUpgradeableProxy(
                    address(rewardManagerImplementation),
                    address(mantaLayerProxyAdmin),
                    abi.encodeWithSelector(
                        RewardManager.initialize.selector,
                        executorMultisig,
                        executorMultisig,
                        executorMultisig,
                        REWARD_MANAGER_STAKE_PERCENTAGE
                    )
                )
            )
        );

        console.log("DeployerBasic _deployFromScratch before msg.sender ", msg.sender);
        console.log("DeployerBasic _deployFromScratch before strategyWhitelister ", strategyManager.strategyWhitelister());
        console.log("DeployerBasic _deployFromScratch before strategyManager.owner() ", strategyManager.owner());
        strategyManager.setStrategyWhitelister(staker);
        address temp_strategyWhitelister = strategyManager.strategyWhitelister();
        console.log("DeployerBasic _deployFromScratch after temp_strategyWhitelister ", temp_strategyWhitelister);
        console.log("DeployerBasic _deployFromScratch after msg.sender ", msg.sender);

        console.log("DeployerBasic _deployFromScratch STRATEGY_MANAGER_WHITELISTER ", STRATEGY_MANAGER_WHITELISTER);
        // Add strategies to whitelist and set whitelister to STRATEGY_MANAGER_WHITELISTER
        strategyManager.addStrategiesToDepositWhitelist(strategiesToWhitelist, thirdPartyTransfersForbiddenValues);
        strategyManager.setStrategyWhitelister(STRATEGY_MANAGER_WHITELISTER);

        // Transfer ownership
        strategyManager.transferOwnership(executorMultisig);
        mantaLayerProxyAdmin.transferOwnership(executorMultisig);

        vm.stopPrank();
    }

//    /**
//   * @notice Register 'sender' as an operator, setting their 'OperatorDetails' in DelegationManager to 'operatorDetails', verifies
//     * that the storage of DelegationManager contract is updated appropriately
//     *
//     * @param sender is the address being registered as an operator
//     * @param operatorDetails is the `sender`'s OperatorDetails struct
//     */
//    function _testRegisterAsOperator(
//        address sender,
//        IDelegationManager.OperatorDetails memory operatorDetails
//    ) public {
//        vm.startPrank(sender);
//        string memory emptyStringForMetadataURI;
//        delegationManager.registerAsOperator(operatorDetails, emptyStringForMetadataURI);
//        assertTrue(delegationManager.isOperator(sender), "testRegisterAsOperator: sender is not a operator");
//
//        assertTrue(
//            keccak256(abi.encode(delegationManager.operatorDetails(sender))) == keccak256(abi.encode(operatorDetails)),
//            "_testRegisterAsOperator: operatorDetails not set appropriately"
//        );
//
//        assertTrue(delegationManager.isDelegated(sender), "_testRegisterAsOperator: sender not marked as actively delegated");
//        vm.stopPrank();
//    }
//
//    /// @notice registers a fixed address as an operator, delegates to it from a second address,
//    ///         and checks that the operator's voteWeights increase properly
//    /// @param operator is the operator being delegated to.
//    /// @param staker is the staker delegating stake to the operator.
//    /// @param ethAmount is the amount of ETH to deposit into the operator's strategy.
//    /// @param eigenAmount is the amount of EIGEN to deposit into the operator's strategy.
//    function _testDelegation(
//        address operator,
//        address staker,
//        uint256 ethAmount,
//        uint256 eigenAmount
//    ) internal {
//        if (!delegationManager.isOperator(operator)) {
//            IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
//                __deprecated_earningsReceiver: operator,
//                delegationApprover: address(0),
//                stakerOptOutWindowBlocks: 0
//            });
//            _testRegisterAsOperator(operator, operatorDetails);
//        }
//
//        uint256 amountBefore = delegationManager.operatorShares(operator, strategyBase1);
//
//        //making additional deposits to the strategies
//        assertTrue(!delegationManager.isDelegated(staker) == true, "testDelegation: staker is not delegate");
//        _testDepositWeth(staker, ethAmount);
//        _testDelegateToOperator(staker, operator);
//        assertTrue(delegationManager.isDelegated(staker) == true, "testDelegation: staker is not delegate");
//
//        (/*IStrategy[] memory updatedStrategies*/, uint256[] memory updatedShares) = strategyManager.getDeposits(staker);
//
//        IStrategyBase _strat = strategyBase1;
//        // IStrategy _strat = strategyManager.stakerStrategyList(staker, 0);
//        assertTrue(address(_strat) != address(0), "stakerStrategyList not updated correctly");
//
//        assertTrue(
//            delegation.operatorShares(operator, _strat) - updatedShares[0] == amountBefore,
//            "ETH operatorShares not updated correctly"
//        );
//    }
//
//    /**
//  * @notice Deposits `amountToDeposit` of WETH from address `sender` into `wethStrat`.
//     * @param sender The address to spoof calls from using `cheats.startPrank(sender)`
//     * @param amountToDeposit Amount of WETH that is first *transferred from this contract to `sender`* and then deposited by `sender` into `stratToDepositTo`
//     */
//    function _testDepositWeth(address sender, uint256 amountToDeposit) internal returns (uint256 amountDeposited) {
//        cheats.assume(amountToDeposit <= wethInitialSupply);
//        amountDeposited = _testDepositToStrategy(sender, amountToDeposit, weth, wethStrat);
//    }
//
//    /**
//     * @notice tries to delegate from 'staker' to 'operator', verifies that staker has at least some shares
//     * delegatedShares update correctly for 'operator' and delegated status is updated correctly for 'staker'
//     * @param staker the staker address to delegate from
//     * @param operator the operator address to delegate to
//     */
//    function _testDelegateToOperator(address staker, address operator) public {
//        //staker-specific information
//        (IStrategyBase[] memory delegateStrategies, uint256[] memory delegateShares) = strategyManager.getDeposits(staker);
//
//        uint256 numStrats = delegateShares.length;
//        assertTrue(numStrats != 0, "_testDelegateToOperator: delegating from address with no deposits");
//        uint256[] memory inititalSharesInStrats = new uint256[](numStrats);
//        for (uint256 i = 0; i < numStrats; ++i) {
//            inititalSharesInStrats[i] = delegationManager.operatorShares(operator, delegateStrategies[i]);
//        }
//
//        vm.startPrank(staker);
//        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry;
//        delegationManager.delegateTo(operator, signatureWithExpiry, bytes32(0));
//        vm.stopPrank();
//
//        assertTrue(
//            delegationManager.delegatedTo(staker) == operator,
//            "_testDelegateToOperator: delegated address not set appropriately"
//        );
//        assertTrue(delegationManager.isDelegated(staker), "_testDelegateToOperator: delegated status not set appropriately");
//
//        for (uint256 i = 0; i < numStrats; ++i) {
//            uint256 operatorSharesBefore = inititalSharesInStrats[i];
//            uint256 operatorSharesAfter = delegationManager.operatorShares(operator, delegateStrategies[i]);
//            assertTrue(
//                operatorSharesAfter == (operatorSharesBefore + delegateShares[i]),
//                "_testDelegateToOperator: delegatedShares not increased correctly"
//            );
//        }
//    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./utils/ExistingDeploymentParser.sol";

/**
 * @notice Script used for the first deployment of MantaLayer core contracts to Manta Network
 * forge script script/DeployerBasic.s.sol --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY --broadcast -vvvv
 * forge script script/DeployerBasic.s.sol --rpc-url $RPC_MANTA --private-key $PRIVATE_KEY --broadcast -vvvv
 * 
 */
contract DeployerBasic is ExistingDeploymentParser {
    function run() external virtual {
        _parseInitialDeploymentParams("script/configs/Deployment.config.json");

        // START RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.startBroadcast();

        emit log_named_address("Deployer Address", msg.sender);

        _deployFromScratch();

        // STOP RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.stopBroadcast();

        // Sanity Checks
        _verifyContractPointers();
        _verifyImplementations();
        _verifyContractsInitialized({isInitialDeployment: true});
        _verifyInitializationParams();

        logAndOutputContractAddresses("script/output/DeploymentBasic.config.json");
    }

    /**
     * @notice Deploy MantaLayer contracts from scratch for Manta Network
     */
    function _deployFromScratch() internal {
        // Deploy ProxyAdmin, later set admins for all proxies to be executorMultisig
        mantaLayerProxyAdmin = new ProxyAdmin(executorMultisig);

        // Set multisigs as pausers, executorMultisig as unpauser
        address[] memory pausers = new address[](3);
        pausers[0] = executorMultisig;
        pausers[1] = operationsMultisig;
        pausers[2] = pauserMultisig;
        address unpauser = executorMultisig;
        mantaLayerPauserReg = new PauserRegistry(pausers, unpauser);

        /**
         * Deploy upgradeable proxy contracts that **will point** to the implementations. Since the implementation contracts are
         * not yet deployed, we give these proxies an empty contract as the initial implementation, to act as if they have no code.
         */
        emptyContract = new EmptyContract();
        TransparentUpgradeableProxy delegationManagerProxyInstance = new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
        delegationManager = DelegationManager(address(delegationManagerProxyInstance));
        delegationManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(delegationManagerProxyInstance)));
        TransparentUpgradeableProxy strategyManagerProxyInstance = new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
        strategyManager = StrategyManager(address(strategyManagerProxyInstance));
        strategyManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(strategyManagerProxyInstance)));
        delegationManagerImplementation = new DelegationManager(strategyManager);
        strategyManagerImplementation = new StrategyManager(delegationManager);

        // Upgrade the proxy contracts to point to the implementations
        IStrategyBase[] memory initializeStrategiesToSetDelayBlocks = new IStrategyBase[](0);
        uint256[] memory initializeWithdrawalDelayBlocks = new uint256[](0);

        // DelegationManager
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
        // StrategyManager
        strategyManagerProxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(payable(address(strategyManager))),
            address(strategyManagerImplementation),
            abi.encodeWithSelector(
                StrategyManager.initialize.selector,
                msg.sender, //initialOwner, set to executorMultisig later after whitelisting strategies
                msg.sender, //initial whitelister, set to STRATEGY_MANAGER_WHITELISTER later
                mantaLayerPauserReg,
                STRATEGY_MANAGER_INIT_PAUSED_STATUS
            )
        );

        // Deploy Strategies
        baseStrategyImplementation = new StrategyBase(strategyManager);
        // whitelist params
        IStrategyBase[] memory strategiesToWhitelist = new IStrategyBase[](numStrategiesToDeploy);
        bool[] memory thirdPartyTransfersForbiddenValues = new bool[](numStrategiesToDeploy);

        for (uint256 i = 0; i < numStrategiesToDeploy; i++) {
            StrategyUnderlyingTokenConfig memory strategyConfig = strategiesToDeploy[i];

            // Deploy and upgrade strategy
            TransparentUpgradeableProxy strategyBaseProxyInstance = new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
            StrategyBase strategy = StrategyBase(address(strategyBaseProxyInstance));
            strategyBaseProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(strategyBaseProxyInstance)));
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

            deployedStrategyArray.push(strategy);
        }

        // Deploy RewardManager proxy and implementation
        rewardManagerImplementation = new RewardManager(
            delegationManager,
            strategyManager,
            IERC20(REWARD_MANAGER_RWARD_TOKEN_ADDRESS),
            REWARD_MANAGER_STAKE_PERCENTAGE
        );
        rewardManager = RewardManager(
            address(
                new TransparentUpgradeableProxy(
                    address(rewardManagerImplementation),
                    address(mantaLayerProxyAdmin),
                    abi.encodeWithSelector(
                        RewardManager.initialize.selector,
                        executorMultisig,
                        executorMultisig,
                        executorMultisig
                    )
                )
            )
        );

        // Add strategies to whitelist and set whitelister to STRATEGY_MANAGER_WHITELISTER
        strategyManager.addStrategiesToDepositWhitelist(strategiesToWhitelist, thirdPartyTransfersForbiddenValues);
        strategyManager.setStrategyWhitelister(STRATEGY_MANAGER_WHITELISTER);

        // Transfer ownership
        strategyManager.transferOwnership(executorMultisig);
        mantaLayerProxyAdmin.transferOwnership(executorMultisig);
    }
}

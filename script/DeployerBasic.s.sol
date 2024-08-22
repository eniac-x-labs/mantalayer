// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./utils/MantaLayerDeploymentHelper.sol";

/**
 * @notice Script used for the first deployment of MantaLayer core contracts to Manta Network
 * forge script script/DeployerBasic.s.sol --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY --broadcast -vvvv
 * forge script script/DeployerBasic.s.sol --rpc-url $RPC_MANTA --private-key $PRIVATE_KEY --broadcast -vvvv
 *
 */
contract DeployerBasic is MantaLayerDeploymentHelper {
    function run() external virtual {
        _matchDeploymentConfigPath();
        _parseInitialDeploymentParams(deploymentConfigPath);
        // START RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.startBroadcast();
        emit log_named_address("Deployer Address", msg.sender);
        _deploy(true);
        // STOP RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.stopBroadcast();
        // Sanity Checks
        _verifyContractPointers();
        _verifyImplementations();
        _verifyContractsInitialized({isInitialDeployment: true});
        _verifyInitializationParams();
        logAndOutputContractAddresses(deploymentConfigOutputPath);
    }

    /// @notice Deploy MantaLayer contracts from scratch
    function _deploy(bool isFromScratch) internal {
        if (isFromScratch) {
            // Set multisigs as pausers, executorMultisig as unpauser
            address[] memory pausers = new address[](3);
            pausers[0] = executorMultisig;
            pausers[1] = operationsMultisig;
            pausers[2] = pauserMultisig;
            address unpauser = executorMultisig;
            mantaLayerPauserReg = new PauserRegistry(pausers, unpauser);
            // Deploy proxies with an empty contract as their implementation temporarily, then update implementation in the following code
            emptyContract = new EmptyContract();
            TransparentUpgradeableProxy delegationManagerProxyInstance =
                new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
            delegationManager = DelegationManager(address(delegationManagerProxyInstance));
            delegationManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(delegationManagerProxyInstance)));
            TransparentUpgradeableProxy strategyManagerProxyInstance =
                new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
            strategyManager = StrategyManager(address(strategyManagerProxyInstance));
            strategyManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(strategyManagerProxyInstance)));
            TransparentUpgradeableProxy rewardManagerProxyInstance =
                new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
            rewardManager = RewardManager(address(rewardManagerProxyInstance));
            rewardManagerProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(rewardManagerProxyInstance)));
            delegationManagerImplementation = new DelegationManager(strategyManager);
            strategyManagerImplementation = new StrategyManager(delegationManager);
            rewardManagerImplementation = new RewardManager(
                delegationManager,
                strategyManager,
                IERC20(REWARD_MANAGER_RWARD_TOKEN_ADDRESS),
                REWARD_MANAGER_STAKE_PERCENTAGE
            );
            // Upgrade the proxy contracts to point to the implementations
            IStrategyBase[] memory initializeStrategiesToSetDelayBlocks = new IStrategyBase[](0);
            uint256[] memory initializeWithdrawalDelayBlocks = new uint256[](0);
            delegationManagerProxyAdmin.upgradeAndCall(
                ITransparentUpgradeableProxy(payable(address(delegationManager))),
                address(delegationManagerImplementation),
                abi.encodeWithSelector(
                    DelegationManager.initialize.selector,
                    msg.sender, // initialOwner, set to executorMultisig later
                    mantaLayerPauserReg,
                    DELEGATION_MANAGER_INIT_PAUSED_STATUS,
                    DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS,
                    initializeStrategiesToSetDelayBlocks,
                    initializeWithdrawalDelayBlocks
                )
            );
            strategyManagerProxyAdmin.upgradeAndCall(
                ITransparentUpgradeableProxy(payable(address(strategyManager))),
                address(strategyManagerImplementation),
                abi.encodeWithSelector(
                    StrategyManager.initialize.selector,
                    msg.sender, //initialOwner, set to executorMultisig later after whitelisting strategies
                    msg.sender //initial whitelister, set to STRATEGY_MANAGER_WHITELISTER later
                )
            );
            rewardManagerProxyAdmin.upgradeAndCall(
                ITransparentUpgradeableProxy(payable(address(rewardManager))),
                address(rewardManagerImplementation),
                abi.encodeWithSelector(
                    RewardManager.initialize.selector,
                    msg.sender, // initialOwner, set to executorMultisig later
                    executorMultisig,
                    executorMultisig
                )
            );
            rewardToken = new ERC20PresetFixedSupply("Reward Token", "RT", 10e50, address(this));
        } else {
            // Retrieve contract instance from addresses in JSON
            mantaLayerPauserReg = PauserRegistry(mantaLayerPauserRegAddress);
            delegationManager = DelegationManager(delegationManagerAddress);
            strategyManager = StrategyManager(strategyManagerAddress);
            rewardManager = RewardManager(rewardManagerAddress);
            emptyContract = EmptyContract(emptyContractAddress);
            rewardToken = ERC20PresetFixedSupply(rewardTokenAddress);
        }
        baseStrategyImplementation = new StrategyBase(strategyManager); // Deployed as the implementation of strategy
        // whitelist params
        IStrategyBase[] memory strategiesToWhitelist = new IStrategyBase[](numStrategiesToDeploy);
        bool[] memory thirdPartyTransfersForbiddenValues = new bool[](numStrategiesToDeploy);
        // Deploy tokens and strategies
        for (uint256 i = 0; i < numStrategiesToDeploy; i++) {
            StrategyUnderlyingTokenConfig memory strategyConfig = strategiesToDeploy[i];
            IERC20 token;
            // If the deployment is not done on mainnet, tokens will be deployed
            if (block.chainid == 169) {
                token = ERC20PresetFixedSupply(strategyConfig.tokenAddress);
            } else {
                // Deploy token
                token = new ERC20PresetFixedSupply(strategyConfig.tokenName, strategyConfig.tokenSymbol, 10e50, address(this));
            }
            deployedTokenArray.push(token);
            // Deploy and upgrade strategy
            TransparentUpgradeableProxy strategyBaseProxyInstance =
                new TransparentUpgradeableProxy(address(emptyContract), executorMultisig, "");
            StrategyBase strategy = StrategyBase(address(strategyBaseProxyInstance));
            strategyBaseProxyAdmin = ProxyAdmin(getProxyAdminAddress(address(strategyBaseProxyInstance)));
            strategyBaseProxyAdmin.upgradeAndCall(
                ITransparentUpgradeableProxy(payable(address(strategy))),
                address(baseStrategyImplementation),
                abi.encodeWithSelector(
                    StrategyBase.initialize.selector,
                    token,
                    mantaLayerPauserReg,
                    STRATEGY_MAX_PER_DEPOSIT,
                    STRATEGY_MAX_TOTAL_DEPOSITS
                )
            );
            strategiesToWhitelist[i] = strategy;
            thirdPartyTransfersForbiddenValues[i] = false;
            deployedStrategyArray.push(strategy);
        }
        // Add strategies to whitelist and set whitelister to STRATEGY_MANAGER_WHITELISTER
        strategyManager.addStrategiesToDepositWhitelist(strategiesToWhitelist, thirdPartyTransfersForbiddenValues);
        strategyManager.setStrategyWhitelister(STRATEGY_MANAGER_WHITELISTER);
        // Transfer ownership
        delegationManager.transferOwnership(executorMultisig);
        strategyManager.transferOwnership(executorMultisig);
        rewardManager.transferOwnership(executorMultisig);
    }

    function _setAddresses(string memory config) internal {
        mantaLayerPauserRegAddress = stdJson.readAddress(config, ".addresses.mantaLayerPauserReg");
        delegationManagerAddress = stdJson.readAddress(config, ".addresses.delegationManager");
        strategyManagerAddress = stdJson.readAddress(config, ".addresses.strategyManager");
        rewardManagerAddress = stdJson.readAddress(config, ".addresses.rewardManager");
        emptyContractAddress = stdJson.readAddress(config, ".addresses.emptyContract");
        rewardTokenAddress = stdJson.readAddress(config, ".addresses.rewardToken");
        operationsMultisig = stdJson.readAddress(config, ".parameters.operationsMultisig");
        executorMultisig = stdJson.readAddress(config, ".parameters.executorMultisig");
    }

    function _deriveStrategyInstance(string memory tokenName) internal view returns (StrategyBase strategy) {
        for (uint256 i = 0; i < deployedStrategyArray.length; i++) {
            if (
                keccak256(abi.encodePacked(IERC20Metadata(address(deployedStrategyArray[i].underlyingToken())).name()))
                    == keccak256(abi.encodePacked(tokenName))
            ) {
                return deployedStrategyArray[i];
            }
        }
        revert("No matching strategy");
    }
}

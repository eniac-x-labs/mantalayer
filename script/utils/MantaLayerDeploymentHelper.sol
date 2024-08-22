// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@/contracts/core/StrategyManager.sol";
import "@/contracts/core/DelegationManager.sol";
import "@/contracts/core/RewardManager.sol";

import "@/contracts/core/StrategyBase.sol";

import "@/access/PauserRegistry.sol";

import "../utils/EmptyContract.sol";
import "@/libraries/ERC20PresetFixedSupply.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

struct StrategyUnderlyingTokenConfig {
    address tokenAddress;
    string tokenName;
    string tokenSymbol;
}

contract MantaLayerDeploymentHelper is Script, Test {
    // Config Path
    string internal deploymentConfigPath;
    string internal deploymentConfigOutputPath;
    // MantaLayer Contracts
    PauserRegistry public mantaLayerPauserReg;
    DelegationManager public delegationManager;
    ProxyAdmin public delegationManagerProxyAdmin;
    DelegationManager public delegationManagerImplementation;
    StrategyManager public strategyManager;
    ProxyAdmin public strategyManagerProxyAdmin;
    StrategyManager public strategyManagerImplementation;
    RewardManager public rewardManager;
    ProxyAdmin public rewardManagerProxyAdmin;
    RewardManager public rewardManagerImplementation;
    ProxyAdmin public strategyBaseProxyAdmin;
    StrategyBase public baseStrategyImplementation;
    UpgradeableBeacon public strategyBeacon;
    EmptyContract public emptyContract;
    ERC20PresetFixedSupply public rewardToken;
    // Roles
    address executorMultisig;
    address operationsMultisig;
    address communityMultisig;
    address pauserMultisig;
    address timelock;
    // Strategies deployed
    uint256 numStrategiesDeployed;
    StrategyBase[] public deployedStrategyArray;
    // Underlying tokens deployed
    IERC20[] public deployedTokenArray;
    // Strategies to deploy
    uint256 numStrategiesToDeploy;
    StrategyUnderlyingTokenConfig[] public strategiesToDeploy; 
    /// @notice Initialization Params for first initial deployment scripts
    // StrategyManager
    uint256 STRATEGY_MANAGER_INIT_PAUSED_STATUS;
    address STRATEGY_MANAGER_WHITELISTER;
    // DelegationManager
    uint256 DELEGATION_MANAGER_INIT_PAUSED_STATUS;
    uint256 DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS;
    // RewardManager
    uint256 REWARD_MANAGER_INIT_PAUSED_STATUS;
    uint32 REWARD_MANAGER_MAX_REWARDS_DURATION;
    uint32 REWARD_MANAGER_MAX_RETROACTIVE_LENGTH;
    uint32 REWARD_MANAGER_MAX_FUTURE_LENGTH;
    uint32 REWARD_MANAGER_GENESIS_REWARDS_TIMESTAMP;
    address REWARD_MANAGER_UPDATER;
    uint32 REWARD_MANAGER_ACTIVATION_DELAY;
    uint32 REWARD_MANAGER_CALCULATION_INTERVAL_SECONDS;
    uint32 REWARD_MANAGER_GLOBAL_OPERATOR_COMMISSION_BIPS;
    address REWARD_MANAGER_RWARD_TOKEN_ADDRESS;
    uint32 REWARD_MANAGER_STAKE_PERCENTAGE;
    // Strategy Deployment
    uint256 STRATEGY_MAX_PER_DEPOSIT;
    uint256 STRATEGY_MAX_TOTAL_DEPOSITS;

    address mantaLayerPauserRegAddress;
    address delegationManagerAddress;
    address strategyManagerAddress;
    address emptyContractAddress;
    address rewardManagerAddress;
    address rewardTokenAddress;

    /// @notice use for parsing already deployed MantaLayer contracts
    function _parseDeployedContracts(string memory existingDeploymentInfoPath) internal virtual {
        // read and log the chainID
        uint256 currentChainId = block.chainid;
        emit log_named_uint("You are parsing on ChainID", currentChainId);

        // READ JSON CONFIG DATA
        string memory existingDeploymentData = vm.readFile(existingDeploymentInfoPath);

        // check that the chainID matches the one in the config
        uint256 configChainId = stdJson.readUint(existingDeploymentData, ".chainInfo.chainId");
        require(configChainId == currentChainId, "You are on the wrong chain for this config");

        // read all of the deployed addresses
        executorMultisig = stdJson.readAddress(existingDeploymentData, ".parameters.executorMultisig");
        operationsMultisig = stdJson.readAddress(existingDeploymentData, ".parameters.operationsMultisig");
        communityMultisig = stdJson.readAddress(existingDeploymentData, ".parameters.communityMultisig");
        pauserMultisig = stdJson.readAddress(existingDeploymentData, ".parameters.pauserMultisig");
        timelock = stdJson.readAddress(existingDeploymentData, ".parameters.timelock");

        mantaLayerPauserReg = PauserRegistry(
            stdJson.readAddress(existingDeploymentData, ".addresses.mantaLayerPauserReg")
        );
        delegationManager = DelegationManager(
            stdJson.readAddress(existingDeploymentData, ".addresses.delegationManager")
        );
        delegationManagerImplementation = DelegationManager(
            stdJson.readAddress(existingDeploymentData, ".addresses.delegationManagerImplementation")
        );
        rewardManager = RewardManager(
            stdJson.readAddress(existingDeploymentData, ".addresses.rewardManager")
        );
        rewardManagerImplementation = RewardManager(
            stdJson.readAddress(existingDeploymentData, ".addresses.rewardManagerImplementation")
        );
        strategyManager = StrategyManager(stdJson.readAddress(existingDeploymentData, ".addresses.strategyManager"));
        strategyManagerImplementation = StrategyManager(
            stdJson.readAddress(existingDeploymentData, ".addresses.strategyManagerImplementation")
        );
        baseStrategyImplementation = StrategyBase(
            stdJson.readAddress(existingDeploymentData, ".addresses.baseStrategyImplementation")
        );
        emptyContract = EmptyContract(stdJson.readAddress(existingDeploymentData, ".addresses.emptyContract"));

        // Strategies Deployed, load strategy list
        numStrategiesDeployed = stdJson.readUint(existingDeploymentData, ".addresses.numStrategiesDeployed");
        for (uint256 i = 0; i < numStrategiesDeployed; ++i) {
            // Form the key for the current element
            string memory key = string.concat(".addresses.strategyAddresses[", vm.toString(i), "]");

            // Use the key and parse the strategy address
            address strategyAddress = abi.decode(stdJson.parseRaw(existingDeploymentData, key), (address));
            deployedStrategyArray.push(StrategyBase(strategyAddress));
        }
    }

    /// @notice use for deploying a new set of MantaLayer contracts
    /// Note that this does require multisigs to already be deployed
    function _parseInitialDeploymentParams(string memory initialDeploymentParamsPath) internal virtual {
        // read and log the chainID
        uint256 currentChainId = block.chainid;
        emit log_named_uint("You are parsing on ChainID", currentChainId);

        // READ JSON CONFIG DATA
        string memory initialDeploymentData = vm.readFile(initialDeploymentParamsPath);

        // check that the chainID matches the one in the config
        uint256 configChainId = stdJson.readUint(initialDeploymentData, ".chainInfo.chainId");
        require(configChainId == currentChainId, "You are on the wrong chain for this config");

        // read all of the deployed addresses
        executorMultisig = stdJson.readAddress(initialDeploymentData, ".multisig_addresses.executorMultisig");
        operationsMultisig = stdJson.readAddress(initialDeploymentData, ".multisig_addresses.operationsMultisig");
        communityMultisig = stdJson.readAddress(initialDeploymentData, ".multisig_addresses.communityMultisig");
        pauserMultisig = stdJson.readAddress(initialDeploymentData, ".multisig_addresses.pauserMultisig");

        // Strategies to Deploy, load strategy list
        numStrategiesToDeploy = stdJson.readUint(initialDeploymentData, ".strategies.numStrategies");
        STRATEGY_MAX_PER_DEPOSIT = stdJson.readUint(initialDeploymentData, ".strategies.MAX_PER_DEPOSIT");
        STRATEGY_MAX_TOTAL_DEPOSITS = stdJson.readUint(initialDeploymentData, ".strategies.MAX_TOTAL_DEPOSITS");
        for (uint256 i = 0; i < numStrategiesToDeploy; ++i) {
            // Form the key for the current element
            string memory key = string.concat(".strategies.strategiesToDeploy[", vm.toString(i), "]");

            // Use parseJson with the key to get the value for the current element
            bytes memory tokenInfoBytes = stdJson.parseRaw(initialDeploymentData, key);

            // Decode the token information into the Token struct
            StrategyUnderlyingTokenConfig memory tokenInfo = abi.decode(
                tokenInfoBytes,
                (StrategyUnderlyingTokenConfig)
            );

            strategiesToDeploy.push(tokenInfo);
        }

        // Read initialize params for upgradeable contracts
        STRATEGY_MANAGER_INIT_PAUSED_STATUS = stdJson.readUint(
            initialDeploymentData,
            ".strategyManager.init_paused_status"
        );
        STRATEGY_MANAGER_WHITELISTER = stdJson.readAddress(
            initialDeploymentData,
            ".strategyManager.init_strategy_whitelister"
        );
        // DelegationManager
        DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS = stdJson.readUint(
            initialDeploymentData,
            ".delegationManager.init_minWithdrawalDelayBlocks"
        );
        DELEGATION_MANAGER_INIT_PAUSED_STATUS = stdJson.readUint(
            initialDeploymentData,
            ".delegationManager.init_paused_status"
        );
        // RewardManager
        REWARD_MANAGER_INIT_PAUSED_STATUS = stdJson.readUint(
            initialDeploymentData,
            ".rewardManager.init_paused_status"
        );
        REWARD_MANAGER_CALCULATION_INTERVAL_SECONDS = uint32(stdJson.readUint(initialDeploymentData, ".rewardManager.CALCULATION_INTERVAL_SECONDS"));
        REWARD_MANAGER_MAX_REWARDS_DURATION = uint32(stdJson.readUint(initialDeploymentData, ".rewardManager.MAX_REWARDS_DURATION"));
        REWARD_MANAGER_MAX_RETROACTIVE_LENGTH = uint32(stdJson.readUint(initialDeploymentData, ".rewardManager.MAX_RETROACTIVE_LENGTH"));
        REWARD_MANAGER_MAX_FUTURE_LENGTH = uint32(stdJson.readUint(initialDeploymentData, ".rewardManager.MAX_FUTURE_LENGTH"));
        REWARD_MANAGER_GENESIS_REWARDS_TIMESTAMP = uint32(stdJson.readUint(initialDeploymentData, ".rewardManager.GENESIS_REWARDS_TIMESTAMP"));
        REWARD_MANAGER_UPDATER = stdJson.readAddress(initialDeploymentData, ".rewardManager.rewards_updater_address");
        REWARD_MANAGER_ACTIVATION_DELAY = uint32(stdJson.readUint(initialDeploymentData, ".rewardManager.activation_delay"));
        REWARD_MANAGER_GLOBAL_OPERATOR_COMMISSION_BIPS = uint32(
            stdJson.readUint(initialDeploymentData, ".rewardManager.global_operator_commission_bips")
        );
        REWARD_MANAGER_RWARD_TOKEN_ADDRESS = stdJson.readAddress(initialDeploymentData, ".rewardManager.reward_token_address");
        REWARD_MANAGER_STAKE_PERCENTAGE = uint32(stdJson.readUint(initialDeploymentData, ".rewardManager.stake_percentage"));
        logInitialDeploymentParams();
    }

    /// @notice Ensure contracts point at each other correctly via constructors
    function _verifyContractPointers() internal view virtual {
        // RewardManager
        require(
            rewardManager.delegationManager() == delegationManager,
            "rewardManager: delegationManager address not set correctly"
        );
        require(
            rewardManager.strategyManager() == strategyManager,
            "rewardManager: strategyManager address not set correctly"
        );
        // DelegationManager
        require(
            delegationManager.strategyManager() == strategyManager,
            "delegationManager: strategyManager address not set correctly"
        );
        // StrategyManager
        require(
            strategyManager.delegation() == delegationManager,
            "strategyManager: delegationManager address not set correctly"
        );
    }

    /// @notice verify implementations for Transparent Upgradeable Proxies
    /// Note that the instance of ProxyAdmin can no longer invoke {getProxyImplementation} in the dependencies from the latest version of OpenZeppelin
    function _verifyImplementations() internal view virtual {
        require(
            getImplementationAddress(address(rewardManager)) == address(rewardManagerImplementation),
            "rewardManager: implementation set incorrectly"
        );
        require(
            getImplementationAddress(address(delegationManager)) == address(delegationManagerImplementation),
            "delegationManager: implementation set incorrectly"
        );
        require(
            getImplementationAddress(address(strategyManager)) == address(strategyManagerImplementation),
            "strategyManager: implementation set incorrectly"
        );

        for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
            require(getImplementationAddress(address(deployedStrategyArray[i])) == address(baseStrategyImplementation),
                "strategy: implementation set incorrectly"
            );
        }
    }

    /**
     * @notice Verify initialization of Transparent Upgradeable Proxies. Also check
     * initialization params if this is the first deployment.
     * @param isInitialDeployment True if this is the first deployment of contracts from scratch
     */
    function _verifyContractsInitialized(bool isInitialDeployment) internal virtual {
        // RewardManager
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        rewardManager.initialize(
            executorMultisig,
            executorMultisig,
            executorMultisig
        );
        // DelegationManager
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        IStrategyBase[] memory initializeStrategiesToSetDelayBlocks = new IStrategyBase[](0);
        uint256[] memory initializeWithdrawalDelayBlocks = new uint256[](0);
        delegationManager.initialize(
            address(0),
            mantaLayerPauserReg,
            0,
            0, // minWithdrawalDelayBLocks
            initializeStrategiesToSetDelayBlocks,
            initializeWithdrawalDelayBlocks
        );
        // StrategyManager
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        strategyManager.initialize(address(0), address(0));
        // Strategies
        for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
            vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
            StrategyBase(address(deployedStrategyArray[i])).initialize(
                IERC20(address(0)),
                mantaLayerPauserReg,
                0,
                0
            );
        }
    }

    /// @notice Verify params based on config constants that are updated from calling `_parseInitialDeploymentParams`
    function _verifyInitializationParams() internal view virtual {
        // RewardManager
        require(
            rewardManager.owner() == executorMultisig,
            "rewardManager: owner not set correctly"
        );
        // DelegationManager
        require(
            delegationManager.pauserRegistry() == mantaLayerPauserReg,
            "delegationManager: pauser registry not set correctly"
        );
        require(delegationManager.owner() == executorMultisig, "delegationManager: owner not set correctly");
        require(
            delegationManager.paused() == DELEGATION_MANAGER_INIT_PAUSED_STATUS,
            "delegationManager: init paused status set incorrectly"
        );
        require(
            delegationManager.minWithdrawalDelayBlocks() == DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS,
            "delegationManager: minWithdrawalDelayBlocks not set correctly"
        );
        // StrategyManager
        require(strategyManager.owner() == executorMultisig, "strategyManager: owner not set correctly");
        if (block.chainid == 1) {
            require(
                strategyManager.strategyWhitelister() == operationsMultisig,
                "strategyManager: strategyWhitelister not set correctly"
            );
        } else if (block.chainid == 17000) {
            // On holesky, for ease of whitelisting we set to executorMultisig
            require(
                strategyManager.strategyWhitelister() == executorMultisig,
                "strategyManager: strategyWhitelister not set correctly"
            );    
        }
        // Strategies
        for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
            require(
                deployedStrategyArray[i].pauserRegistry() == mantaLayerPauserReg,
                "StrategyBase: pauser registry not set correctly"
            );
            require(
                deployedStrategyArray[i].paused() == 0,
                "StrategyBase: init paused status set incorrectly"
            );
            require(
                strategyManager.strategyIsWhitelistedForDeposit(deployedStrategyArray[i]),
                "StrategyBase: strategy should be whitelisted"
            );
        }

        // Pausing Permissions
        require(mantaLayerPauserReg.isPauser(operationsMultisig), "pauserRegistry: operationsMultisig is not pauser");
        require(mantaLayerPauserReg.isPauser(executorMultisig), "pauserRegistry: executorMultisig is not pauser");
        require(mantaLayerPauserReg.isPauser(pauserMultisig), "pauserRegistry: pauserMultisig is not pauser");
        require(mantaLayerPauserReg.unpauser() == executorMultisig, "pauserRegistry: unpauser not set correctly");
    }

    function logInitialDeploymentParams() public {
        emit log_string("==== Parsed Initilize Params for Initial Deployment ====");

        emit log_named_address("executorMultisig", executorMultisig);
        emit log_named_address("operationsMultisig", operationsMultisig);
        emit log_named_address("communityMultisig", communityMultisig);
        emit log_named_address("pauserMultisig", pauserMultisig);

        emit log_named_uint("STRATEGY_MANAGER_INIT_PAUSED_STATUS", STRATEGY_MANAGER_INIT_PAUSED_STATUS);
        emit log_named_address("STRATEGY_MANAGER_WHITELISTER", STRATEGY_MANAGER_WHITELISTER);
        emit log_named_uint(
            "DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS",
            DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS
        );
        emit log_named_uint("DELEGATION_MANAGER_INIT_PAUSED_STATUS", DELEGATION_MANAGER_INIT_PAUSED_STATUS);
        emit log_named_uint("REWARD_MANAGER_INIT_PAUSED_STATUS", REWARD_MANAGER_INIT_PAUSED_STATUS);

        emit log_string("==== Strategies to Deploy ====");
        for (uint256 i = 0; i < numStrategiesToDeploy; ++i) {
            // Decode the token information into the Token struct
            StrategyUnderlyingTokenConfig memory tokenInfo = strategiesToDeploy[i];

            strategiesToDeploy.push(tokenInfo);
            emit log_named_address("TOKEN ADDRESS", tokenInfo.tokenAddress);
            emit log_named_string("TOKEN NAME", tokenInfo.tokenName);
            emit log_named_string("TOKEN SYMBOL", tokenInfo.tokenSymbol);
        }
    }

    /**
     * @notice Log contract addresses and write to output json file
     */
    function logAndOutputContractAddresses(string memory outputPath) public {
        string memory parent_object = "parent object";
        // JSON field: parameters
        string memory parameters = "parameters";
        vm.serializeAddress(parameters, "executorMultisig", executorMultisig);
        vm.serializeAddress(parameters, "operationsMultisig", operationsMultisig);
        vm.serializeAddress(parameters, "communityMultisig", communityMultisig);
        vm.serializeAddress(parameters, "pauserMultisig", pauserMultisig);
        vm.serializeAddress(parameters, "timelock", timelock);
        string memory parameters_output = vm.serializeAddress(parameters, "operationsMultisig", operationsMultisig);
        // JSON field: chainInfo
        string memory chain_info = "chainInfo";
        vm.serializeUint(chain_info, "deploymentBlock", block.number);
        string memory chain_info_output = vm.serializeUint(chain_info, "chainId", block.chainid);
        // JSON field: addresses
        string memory deployed_addresses = "addresses";
        vm.serializeAddress(deployed_addresses, "mantaLayerPauserReg", address(mantaLayerPauserReg));
        vm.serializeAddress(deployed_addresses, "delegationManager", address(delegationManager));
        vm.serializeAddress(
            deployed_addresses,
            "delegationManagerImplementation",
            address(delegationManagerImplementation)
        );
        vm.serializeAddress(deployed_addresses, "strategyManager", address(strategyManager));
        vm.serializeAddress(
            deployed_addresses,
            "strategyManagerImplementation",
            address(strategyManagerImplementation)
        );
        vm.serializeAddress(deployed_addresses, "rewardManager", address(rewardManager));
        vm.serializeAddress(
            deployed_addresses,
            "rewardManagerImplementation",
            address(rewardManagerImplementation)
        );
        vm.serializeAddress(deployed_addresses, "baseStrategyImplementation", address(baseStrategyImplementation));
        vm.serializeAddress(deployed_addresses, "emptyContract", address(emptyContract));
        vm.serializeAddress(deployed_addresses, "rewardToken", address(rewardToken));
        // JSON field(sub-field): strategies
        string memory deployed_strategies = "strategies";
        for (uint256 i = 0; i < numStrategiesToDeploy; ++i) {
            vm.serializeAddress(
                deployed_strategies,
                strategiesToDeploy[i].tokenSymbol,
                address(deployedStrategyArray[i])
            );
        }
        string memory deployed_strategies_output = numStrategiesToDeploy == 0
            ? ""
            : vm.serializeAddress(
                deployed_strategies,
                strategiesToDeploy[numStrategiesToDeploy - 1].tokenSymbol,
                address(deployedStrategyArray[numStrategiesToDeploy - 1])
            );
        // JSON field(sub-field): underlyingTokens
        string memory underlying_tokens = "underlyingTokens";
        for (uint256 i = 0; i < deployedTokenArray.length; ++i) {
            vm.serializeAddress(
                underlying_tokens,
                IERC20Metadata(address(deployedTokenArray[i])).symbol(),
                address(deployedTokenArray[i])
            );
        }
        string memory deployed_underlying_token_output = deployedTokenArray.length == 0
            ? ""
            : vm.serializeAddress(
                underlying_tokens,
                IERC20Metadata(address(deployedTokenArray[deployedTokenArray.length - 1])).symbol(),
                address(deployedTokenArray[deployedTokenArray.length - 1])
            );
        vm.serializeString(
            deployed_addresses,
            "strategies",
            deployed_strategies_output
        );
        string memory deployed_addresses_output = vm.serializeString(
            deployed_addresses,
            "underlyingTokens",
            deployed_underlying_token_output
        );
        // serialize all the data
        vm.serializeString(parent_object, deployed_addresses, deployed_addresses_output);
        vm.serializeString(parent_object, chain_info, chain_info_output);
        string memory finalJson = vm.serializeString(parent_object, parameters, parameters_output);

        vm.writeJson(finalJson, outputPath);
    }

    function getProxyAdminAddress(address proxy) internal view returns (address) {
        // Cheatcode address of Foundry
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm _vm = Vm(CHEATCODE_ADDRESS);

        bytes32 adminSlot = _vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }

    function getImplementationAddress(address proxy) internal view returns (address) {
        // Cheatcode address of Foundry
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm _vm = Vm(CHEATCODE_ADDRESS);

        bytes32 implementationSlot = _vm.load(proxy, ERC1967Utils.IMPLEMENTATION_SLOT);
        return address(uint160(uint256(implementationSlot)));
    }

    // Overwrite multisig to be a single EOA for testing.
    function multisigToEOAForTesting(address EOAAddress) internal {
        executorMultisig = EOAAddress;
        operationsMultisig = EOAAddress;
        pauserMultisig = EOAAddress;
        communityMultisig = EOAAddress;
        STRATEGY_MANAGER_WHITELISTER = EOAAddress;
    }

    function _matchDeploymentConfigPath() internal {
        if (block.chainid == 169) {
            deploymentConfigPath = "script/configs/Deployment_Manta_Mainnet.config.json";
            deploymentConfigOutputPath = "script/output/DeploymentOutput_Manta_Mainnet.config.json";
        } else if (block.chainid == 3441006) {
            deploymentConfigPath = "script/configs/Deployment_Manta_Sepolia.config.json";
            deploymentConfigOutputPath = "script/output/DeploymentOutput_Manta_Sepolia.config.json";
        } else if (block.chainid == 31337) {
            deploymentConfigPath = "script/configs/Deployment_Local.config.json";
            deploymentConfigOutputPath = "script/output/DeploymentOutput_Local.config.json";
        }
    }
    
}

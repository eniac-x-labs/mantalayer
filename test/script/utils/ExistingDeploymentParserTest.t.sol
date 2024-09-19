// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import "@/access/PauserRegistry.sol";
import "@/contracts/core/StrategyBase.sol";
import "@/contracts/core/StrategyManager.sol";
import "@/contracts/core/DelegationManager.sol";
import "@/contracts/core/RewardManager.sol";

import "@test/script/utils/EmptyContract.sol";
import "@test/TestERC20Helper.t.sol";

    struct StrategyUnderlyingTokenConfig {
        address tokenAddress;
        string tokenName;
        string tokenSymbol;
    }

contract ExistingDeploymentParserTest is Script, Test {
    address public constant TEST_ZERO_ADDRESS = address(0x0);
    /// @dev EOAowner is the deployer and owner of the contracts
    address public constant staker = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
    uint32  public constant staker_index = 9;

    address public constant EARNINGS_RECEIVER = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    uint32  public constant EARNINGS_RECEIVER_index = 0;

    address public constant DELEGATION_APPROVER = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    uint32  public constant DELEGATION_APPROVER_index = 1;

    address public constant operator = address(0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65);
    uint32  public constant operator_index = 4;

    TestERC20Helper public erc20TestToken;

    // "empty" / zero salt, reused across many tests
    bytes32 emptySalt;

    // MantaLayer Contracts
    ProxyAdmin public mantaLayerProxyAdmin;

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

    EmptyContract public emptyContract;

    // Reward Token
//    address public rewardTokenAddress;

    address executorMultisig;
    address operationsMultisig;
    address communityMultisig;
    address pauserMultisig;
    address timelock;

    // strategies deployed
//    uint256 numStrategiesDeployed;
    StrategyBase[] public deployedStrategyArray;
    StrategyBase public strategyBase1;
    // Strategies to Deploy
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

    // one week in blocks -- 50400
//    uint32 DELAYED_WITHDRAWAL_ROUTER_INIT_WITHDRAWAL_DELAY_BLOCKS;

    // Strategy Deployment
    uint256 STRATEGY_MAX_PER_DEPOSIT;
    uint256 STRATEGY_MAX_TOTAL_DEPOSITS;

    function _parseInitialDeploymentParams() internal virtual {
        vm.startPrank(staker);
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams address(this):", address(this));
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams msg.sender:", msg.sender);

        executorMultisig = staker;
        operationsMultisig = staker;
        communityMultisig = staker;
        pauserMultisig = staker;
        timelock = staker;

        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams EOAowner:", staker);

        uint256 EOAowner_balance = staker.balance;
        console.log("_parseInitialDeploymentParams EOAowner_balance :", EOAowner_balance);

        string memory token_name = "TestToken";
        string memory token_symbol = "TTK";
        erc20TestToken = new TestERC20Helper("TestToken", "TTK", 12345678910 * 1e18, staker);
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams erc20TestToken:", address(erc20TestToken));

//        erc20TestToken.approve(EARNINGS_RECEIVER, 100 * 1e18);
//        erc20TestToken.transfer(EARNINGS_RECEIVER, 100 * 1e18);
//        erc20TestToken.approve(DELEGATION_APPROVER, 100 * 1e18);
//        erc20TestToken.transfer(DELEGATION_APPROVER, 100 * 1e18);
//        erc20TestToken.approve(operator, 100 * 1e18);
//        erc20TestToken.transfer(operator, 100 * 1e18);
//        don't transfer address(0)
//        erc20TestToken.approve(TEST_ZERO_ADDRESS, 100 * 1e18);
//        erc20TestToken.transfer(TEST_ZERO_ADDRESS, 100 * 1e18);

        numStrategiesToDeploy = 1;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams numStrategiesToDeploy:", numStrategiesToDeploy);
        STRATEGY_MAX_PER_DEPOSIT = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
        STRATEGY_MAX_TOTAL_DEPOSITS = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams STRATEGY_MAX_PER_DEPOSIT:", STRATEGY_MAX_PER_DEPOSIT);
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams STRATEGY_MAX_TOTAL_DEPOSITS:", STRATEGY_MAX_TOTAL_DEPOSITS);

        StrategyUnderlyingTokenConfig memory tokenInfo = StrategyUnderlyingTokenConfig({
            tokenAddress: address(erc20TestToken),
            tokenName: token_name,
            tokenSymbol: token_symbol
        });
        strategiesToDeploy.push(tokenInfo);

        STRATEGY_MANAGER_INIT_PAUSED_STATUS = 0;
        STRATEGY_MANAGER_WHITELISTER = staker;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams STRATEGY_MANAGER_INIT_PAUSED_STATUS:", STRATEGY_MANAGER_INIT_PAUSED_STATUS);
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams STRATEGY_MANAGER_WHITELISTER:", STRATEGY_MANAGER_WHITELISTER);

        DELEGATION_MANAGER_INIT_PAUSED_STATUS = 0;
        DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS = 50400;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams DELEGATION_MANAGER_INIT_PAUSED_STATUS:", DELEGATION_MANAGER_INIT_PAUSED_STATUS);
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS:", DELEGATION_MANAGER_MIN_WITHDRAWAL_DELAY_BLOCKS);

        REWARD_MANAGER_INIT_PAUSED_STATUS = 0;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_INIT_PAUSED_STATUS:", REWARD_MANAGER_INIT_PAUSED_STATUS);
        REWARD_MANAGER_CALCULATION_INTERVAL_SECONDS = 604800;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_CALCULATION_INTERVAL_SECONDS:", REWARD_MANAGER_CALCULATION_INTERVAL_SECONDS);
        REWARD_MANAGER_MAX_REWARDS_DURATION = 6048000;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_MAX_REWARDS_DURATION:", REWARD_MANAGER_MAX_REWARDS_DURATION);
        REWARD_MANAGER_MAX_RETROACTIVE_LENGTH = 7776000;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_MAX_RETROACTIVE_LENGTH:", REWARD_MANAGER_MAX_RETROACTIVE_LENGTH);

        REWARD_MANAGER_MAX_FUTURE_LENGTH = 2592000;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_MAX_FUTURE_LENGTH:", REWARD_MANAGER_MAX_FUTURE_LENGTH);

        REWARD_MANAGER_GENESIS_REWARDS_TIMESTAMP = 1710979200;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_GENESIS_REWARDS_TIMESTAMP:", REWARD_MANAGER_GENESIS_REWARDS_TIMESTAMP);

        REWARD_MANAGER_UPDATER = staker;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_UPDATER:", REWARD_MANAGER_UPDATER);

        REWARD_MANAGER_ACTIVATION_DELAY = 7200;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_ACTIVATION_DELAY:", REWARD_MANAGER_ACTIVATION_DELAY);

        REWARD_MANAGER_GLOBAL_OPERATOR_COMMISSION_BIPS = 1000;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_GLOBAL_OPERATOR_COMMISSION_BIPS:", REWARD_MANAGER_GLOBAL_OPERATOR_COMMISSION_BIPS);

        REWARD_MANAGER_RWARD_TOKEN_ADDRESS = EARNINGS_RECEIVER;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_RWARD_TOKEN_ADDRESS:", REWARD_MANAGER_RWARD_TOKEN_ADDRESS);

        REWARD_MANAGER_STAKE_PERCENTAGE = 1;
        console.log("ExistingDeploymentParserTest _parseInitialDeploymentParams REWARD_MANAGER_STAKE_PERCENTAGE:", REWARD_MANAGER_STAKE_PERCENTAGE);

        vm.stopPrank();
    }

    function getProxyAdminAddress(address proxy) internal view returns (address) {
        // Cheatcode address of Foundry
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        bytes32 adminSlot = vm.load(proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }

    function getImplementationAddress(address proxy) internal view returns (address) {
        // Cheatcode address of Foundry
        address CHEATCODE_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
        Vm vm = Vm(CHEATCODE_ADDRESS);

        bytes32 implementationSlot = vm.load(proxy, ERC1967Utils.IMPLEMENTATION_SLOT);
        return address(uint160(uint256(implementationSlot)));
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

        // for (uint256 i = 0; i < deployedStrategyArray.length; ++i) {
        //     require(
        //         TransparentUpgradeableProxy(payable(address(deployedStrategyArray[i])))._implementation()
        //         == address(baseStrategyImplementation),
        //         "strategy: implementation set incorrectly"
        //     );
        // }
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
            executorMultisig,
            REWARD_MANAGER_STAKE_PERCENTAGE
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

}

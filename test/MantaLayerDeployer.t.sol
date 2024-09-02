// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "@/libraries/ERC20PresetFixedSupply.sol";
import "@/contracts/interfaces/IDelegationManager.sol";
import "@/contracts/core/DelegationManager.sol";

import "@/contracts/core/StrategyManager.sol";
import "@/contracts/core/StrategyBase.sol";

import "@/access/PauserRegistry.sol";

import "./utils/Operators.sol";
import "../script/DeployerBasic.s.sol";

import "forge-std/Test.sol";

contract MantaLayerDeployer is DeployerBasic, Operators {
    mapping(uint256 => IStrategyBase) public strategies;
    IERC20 public wmanta;
    uint256 MantaTotalSupply = 10e50;
    StrategyBase public wmantaStrat;
    //from testing seed phrase
    bytes32 priv_key_0 = 0x1234567812345678123456781234567812345678123456781234567812345678;
    bytes32 priv_key_1 = 0x1234567812345678123456781234567812345698123456781234567812348976;

    //strategy indexes for undelegation (see commitUndelegation function)
    uint256[] public strategyIndexes;
    address[2] public stakers;

    IStrategyBase[] public initializeStrategiesToSetDelayBlocks;
    uint256[] public initializeWithdrawalDelayBlocks;
    uint256 minWithdrawalDelayBlocks = 0;
    uint256 REQUIRED_BALANCE_WEI = 32 ether;
    uint64 MAX_PARTIAL_WTIHDRAWAL_AMOUNT_GWEI = 1 ether / 1e9;
    uint64 MAX_RESTAKED_BALANCE_GWEI_PER_VALIDATOR = 32e9;

    address theMultiSig = address(420);
    address operator = address(0x4206904396bF2f8b173350ADdEc5007A52664293); //sk: e88d9d864d5d731226020c5d2f02b62a4ce2a4534a39c225d32d3db795f83319
    address acct_0 = vm.addr(uint256(priv_key_0));
    address acct_1 = vm.addr(uint256(priv_key_1));
    address _challenger = address(0x6966904396bF2f8b173350bCcec5007A52669873);
    address public mantaLayerReputedMultisig = address(this);

    // addresses excluded from fuzzing due to abnormal behavior.
    mapping(address => bool) fuzzedAddressMapping;

    //ensures that a passed in address is not set to true in the fuzzedAddressMapping
    modifier fuzzedAddress(address addr) virtual {
        vm.assume(fuzzedAddressMapping[addr] == false);
        _;
    }

    modifier cannotReinit() {
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        _;
    }

    function setUp() public virtual {
        _matchDeploymentConfigPath();
        try vm.envUint("CHAIN_ID") returns (uint256 chainId) {
            if (chainId == 31337 || chainId == 3441006 || chainId == 17000) {
                _deployMantaLayerContractsFromScratch();
            } else if (chainId == 169) {
                _retrieveDeployedMantaLayerContracts();
            }
            // If CHAIN_ID ENV is not set, assume local deployment on 31337
        } catch {
            _deployMantaLayerContractsFromScratch();
        }
        fuzzedAddressMapping[address(0)] = true;
        fuzzedAddressMapping[address(rewardManager)] = true;
        fuzzedAddressMapping[address(strategyManager)] = true;
        fuzzedAddressMapping[address(delegationManager)] = true;
    }

    function _retrieveDeployedMantaLayerContracts() internal {
        _matchDeploymentConfigPath();
        _parseInitialDeploymentParams(deploymentConfigPath);
        _setAddresses(vm.readFile(deploymentConfigOutputPath));
        multisigToEOAForTesting(msg.sender);
        // Deploy MantaLayer contracts(including relevent tokens)
        vm.startBroadcast();
        emit log_named_address("Deployer and EOAowner Address", msg.sender);
        _deploy(false);   // Execute deployment
        vm.stopBroadcast();
        _verifyContractPointers();
        _verifyImplementations();
        _verifyContractsInitialized();
        _verifyInitializationParams(); // override to check contract.owner() is EOAowner instead
        logAndOutputContractAddresses(deploymentConfigOutputPath);
        // Derive strategies
        wmantaStrat = _deriveStrategyInstance("Wrapped Manta");
        // Prepare stakers
        stakers = [acct_0, acct_1];
    }

    function _deployMantaLayerContractsFromScratch() internal {
        _matchDeploymentConfigPath();
        _parseInitialDeploymentParams(deploymentConfigPath);
        multisigToEOAForTesting(msg.sender);
        // Deploy MantaLayer contracts(including relevent tokens)
        vm.startBroadcast();
        emit log_named_address("Deployer and EOAowner Address", msg.sender);
        _deploy(true);   // Execute deployment
        vm.stopBroadcast();
        _verifyContractPointers();
        _verifyImplementations();
        _verifyContractsInitialized();
        _verifyInitializationParams(); // override to check contract.owner() is EOAowner instead
        logAndOutputContractAddresses(deploymentConfigOutputPath);
        // Derive strategies
        wmantaStrat = _deriveStrategyInstance("Wrapped Manta");
        // Prepare stakers
        stakers = [acct_0, acct_1];
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../script/DeployerBasic.s.sol";
import "../mocks/StrategyManagerMock.sol";

abstract contract MantaLayerUnitTestSetup is DeployerBasic {
    StrategyManagerMock public strategyManagerMock;
    mapping(address => bool) public addressIsExcludedFromFuzzedInputs;

    modifier filterFuzzedAddressInputs(address fuzzedAddress) {
        vm.assume(!addressIsExcludedFromFuzzedInputs[fuzzedAddress]);
        _;
    }
    
    function setUp() public virtual {
        _matchDeploymentConfigPath();
        _parseInitialDeploymentParams(deploymentConfigPath);
        // Overwrite multisig to be EOAowner
        address EOAowner = msg.sender;
        multisigToEOAForTesting(EOAowner);
        // START RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.startBroadcast();
        emit log_named_address("Deployer and EOAowner Address", EOAowner);
        _deploy(true);
        // STOP RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.stopBroadcast();
        // Sanity Checks
        _verifyContractPointers();
        _verifyImplementations();
        _verifyContractsInitialized();
        _verifyInitializationParams(); // override to check contract.owner() is EOAowner instead
        logAndOutputContractAddresses(deploymentConfigOutputPath);
        // Initialize mocks
        strategyManagerMock = new StrategyManagerMock();
        // Exclude the addresses of deployed contracts
        addressIsExcludedFromFuzzedInputs[address(0)] = true;
        addressIsExcludedFromFuzzedInputs[address(mantaLayerPauserReg)] = true;
        addressIsExcludedFromFuzzedInputs[address(delegationManager)] = true;
        addressIsExcludedFromFuzzedInputs[address(strategyManager)] = true;
        addressIsExcludedFromFuzzedInputs[address(rewardManager)] = true;
        addressIsExcludedFromFuzzedInputs[address(emptyContract)] = true;
        addressIsExcludedFromFuzzedInputs[address(rewardToken)] = true;
    }
}

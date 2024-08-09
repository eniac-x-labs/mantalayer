// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./DeployerBasic.s.sol";

/**
 * @notice Script used for the first deployment of MantaLayer core contracts to Manta Network
 * forge script script/DeployerMantaLayer.s.sol --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY --broadcast -vvvv
 * forge script script/DeployerMantaLayer.s.sol --rpc-url $RPC_MANTA --private-key $PRIVATE_KEY --broadcast -vvvv
 *
 * Script for dev environment, exact same as DeployerBasic.s.sol but with an EOAowner
 * instead of multisig addresses for permissions.
 * Unused config fields:
 * - init_strategy_whitelister
 * - multisig_addresses(operations, pauser, executor, community)
 */
contract DeployerMantaLayer is DeployerBasic {
    /// @dev EOAowner is the deployer and owner of the contracts
    address EOAowner;

    function run() external virtual override {
        _parseInitialDeploymentParams("script/configs/Deployment.config.json");

        // Overwrite multisig to be EOAowner
        EOAowner = msg.sender;
        executorMultisig = EOAowner;
        operationsMultisig = EOAowner;
        pauserMultisig = EOAowner;
        communityMultisig = EOAowner;
        STRATEGY_MANAGER_WHITELISTER = EOAowner;

        // START RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.startBroadcast();

        emit log_named_address("Deployer and EOAowner Address", EOAowner);

        _deployFromScratch();

        // STOP RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.stopBroadcast();

        // Sanity Checks
        _verifyContractPointers();
        // _verifyImplementations();
        _verifyContractsInitialized({isInitialDeployment: true});
        _verifyInitializationParams(); // override to check contract.owner() is EOAowner instead

        logAndOutputContractAddresses("script/output/DeploymentMantaLayer.config.json");
    }
}

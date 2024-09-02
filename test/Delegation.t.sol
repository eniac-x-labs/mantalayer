// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/mocks/ERC1271WalletMock.sol";
import "src/contracts/interfaces/ISignatureUtils.sol";

import "../test/MantaLayerTestHelper.t.sol";

contract DelegationTests is MantaLayerTestHelper {
    uint256 public PRIVATE_KEY = 420;

    uint32 serveUntil = 100;

    address public registryCoordinator = address(uint160(uint256(keccak256("registryCoordinator"))));
    uint8 defaultQuorumNumber = 0;
    bytes32 defaultOperatorId = bytes32(uint256(0));

    modifier fuzzedAmounts(uint256 mantaAmount) {
        vm.assume(mantaAmount >= 0 && mantaAmount <= 1e18);
        _;
    }

    function setUp() public virtual override {
        MantaLayerDeployer.setUp();
    }

    /// @notice testing if an operator can register to themselves.
    function testSelfOperatorRegister() public {
        _testRegisterAdditionalOperator(0);
    }

    /// @notice testing if an operator can delegate to themselves.
    /// @param sender is the address of the operator.
    function testSelfOperatorDelegate(address sender) public {
        vm.assume(sender != address(0));
        vm.assume(sender != address(delegationManagerProxyAdmin));
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            earningsReceiver: sender,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });
        _testRegisterAsOperator(sender, operatorDetails);
    }

    function testTwoSelfOperatorsRegister() public {
        _testRegisterAdditionalOperator(0);
        _testRegisterAdditionalOperator(1);
    }

    /// @notice registers a fixed address as a delegate, delegates to it from a second address,
    ///         and checks that the delegate's voteWeights increase properly
    /// @param operator is the operator being delegated to.
    /// @param staker is the staker delegating stake to the operator.
    function testDelegation(
        address operator,
        address staker,
        uint96 mantaAmount
    ) public fuzzedAddress(operator) fuzzedAddress(staker) fuzzedAmounts(mantaAmount) {
        vm.assume(staker != operator);
        // base strategy will revert if these amounts are too small on first deposit
        vm.assume(mantaAmount >= 2);

        // Set weights ahead of the helper function call
        bytes memory quorumNumbers = new bytes(2);
        quorumNumbers[0] = bytes1(uint8(0));
        quorumNumbers[0] = bytes1(uint8(1));
        _testDelegation(operator, staker, mantaAmount);
    }

    /// @notice tests that a when an operator is delegated to, that delegationManager is properly accounted for.
    function testDelegationReceived(
        address _operator,
        address staker,
        uint64 mantaAmount
    ) public fuzzedAddress(_operator) fuzzedAddress(staker) fuzzedAmounts(mantaAmount) {
        vm.assume(staker != _operator);
        vm.assume(mantaAmount >= 2);

        // use storage to solve stack-too-deep
        operator = _operator;

        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            earningsReceiver: operator,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });
        if (!delegationManager.isOperator(operator)) {
            _testRegisterAsOperator(operator, operatorDetails);
        }

        uint256 amountBefore = delegationManager.operatorShares(operator, wmantaStrat);

        //making additional deposits to the  strategies
        assertTrue(!delegationManager.isDelegated(staker) == true, "testDelegation: staker is not delegate");
        _testDepositManta(staker, mantaAmount);
        _testDelegateToOperator(staker, operator);
        assertTrue(delegationManager.isDelegated(staker) == true, "testDelegation: staker is not delegate");

        (/*IStrategyBase[] memory updatedStrategies*/, uint256[] memory updatedShares) = strategyManager.getDeposits(staker);

        {
            IStrategyBase _strat = wmantaStrat;
            // IStrategyBase _strat = strategyManager.stakerStrats(staker, 0);
            assertTrue(address(_strat) != address(0), "stakerStrats not updated correctly");

            assertTrue(
                delegationManager.operatorShares(operator, _strat) - updatedShares[0] == amountBefore,
                "ETH operatorShares not updated correctly"
            );

            vm.startPrank(address(strategyManager));

            IDelegationManager.OperatorDetails memory expectedOperatorDetails = delegationManager.operatorDetails(operator);
            assertTrue(
                keccak256(abi.encode(expectedOperatorDetails)) == keccak256(abi.encode(operatorDetails)),
                "failed to set correct operator details"
            );
        }
    }

    /// @notice tests that a when an operator is undelegated from, that the staker is properly classified as undelegated.
    function testUndelegation(
        address operator,
        address staker,
        uint96 mantaAmount
    ) public fuzzedAddress(operator) fuzzedAddress(staker) fuzzedAmounts(mantaAmount) {
        vm.assume(staker != operator);
        // base strategy will revert if these amounts are too small on first deposit
        vm.assume(mantaAmount >= 1);
        _testDelegation(operator, staker, mantaAmount);

        (IStrategyBase[] memory strategyArray, uint256[] memory shareAmounts) = strategyManager.getDeposits(staker);
        uint256[] memory strategyIndexes = new uint256[](strategyArray.length);

        // withdraw shares
        _testQueueWithdrawal(staker, strategyIndexes, strategyArray, shareAmounts, staker /*withdrawer*/);

        vm.startPrank(staker);
        delegationManager.undelegate(staker);
        vm.stopPrank();

        require(delegationManager.delegatedTo(staker) == address(0), "undelegation unsuccessful");
    }

    /// @notice tests delegationManager from a staker to operator via ECDSA signature.
    function testDelegateToBySignature(
        address operator,
        uint96 mantaAmount,
        uint256 expiry
    ) public fuzzedAddress(operator) {
        address staker = vm.addr(PRIVATE_KEY);
        _registerOperatorAndDepositFromStaker(operator, staker, mantaAmount);

        uint256 nonceBefore = delegationManager.stakerNonce(staker);

        bytes32 structHash = keccak256(
            abi.encode(delegationManager.STAKER_DELEGATION_TYPEHASH(), staker, operator, nonceBefore, expiry)
        );
        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", delegationManager.domainSeparator(), structHash));

        bytes memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digestHash);
            signature = abi.encodePacked(r, s, v);
        }

        if (expiry < block.timestamp) {
            vm.expectRevert("DelegationManager.delegateToBySignature: staker signature expired");
        }
        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils.SignatureWithExpiry({
            signature: signature,
            expiry: expiry
        });
        delegationManager.delegateToBySignature(staker, operator, signatureWithExpiry, signatureWithExpiry, bytes32(0));
        if (expiry >= block.timestamp) {
            assertTrue(delegationManager.isDelegated(staker) == true, "testDelegation: staker is not delegate");
            assertTrue(nonceBefore + 1 == delegationManager.stakerNonce(staker), "nonce not incremented correctly");
            assertTrue(delegationManager.delegatedTo(staker) == operator, "staker delegated to wrong operator");
        }
    }

    /// @notice tries delegating using a signature and an EIP 1271 compliant wallet
    function testDelegateToBySignature_WithContractWallet_Successfully(
        address operator,
        uint96 mantaAmount
    ) public fuzzedAddress(operator) {
        address staker = vm.addr(PRIVATE_KEY);

        // deploy ERC1271WalletMock for staker to use
        vm.startPrank(staker);
        ERC1271WalletMock wallet = new ERC1271WalletMock(staker);
        vm.stopPrank();
        staker = address(wallet);

        _registerOperatorAndDepositFromStaker(operator, staker, mantaAmount);

        uint256 nonceBefore = delegationManager.stakerNonce(staker);

        bytes32 structHash = keccak256(
            abi.encode(delegationManager.STAKER_DELEGATION_TYPEHASH(), staker, operator, nonceBefore, type(uint256).max)
        );
        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", delegationManager.domainSeparator(), structHash));

        bytes memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digestHash);
            signature = abi.encodePacked(r, s, v);
        }

        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils.SignatureWithExpiry({
            signature: signature,
            expiry: type(uint256).max
        });
        delegationManager.delegateToBySignature(staker, operator, signatureWithExpiry, signatureWithExpiry, bytes32(0));
        assertTrue(delegationManager.isDelegated(staker) == true, "testDelegation: staker is not delegate");
        assertTrue(nonceBefore + 1 == delegationManager.stakerNonce(staker), "nonce not incremented correctly");
        assertTrue(delegationManager.delegatedTo(staker) == operator, "staker delegated to wrong operator");
    }

    ///  @notice tries delegating using a signature and an EIP 1271 compliant wallet, *but* providing a bad signature
    function testDelegateToBySignature_WithContractWallet_BadSignature(
        address operator,
        uint96 mantaAmount
    ) public fuzzedAddress(operator) {
        address staker = vm.addr(PRIVATE_KEY);

        // deploy ERC1271WalletMock for staker to use
        vm.startPrank(staker);
        ERC1271WalletMock wallet = new ERC1271WalletMock(staker);
        vm.stopPrank();
        staker = address(wallet);

        _registerOperatorAndDepositFromStaker(operator, staker, mantaAmount);

        uint256 nonceBefore = delegationManager.stakerNonce(staker);

        bytes32 structHash = keccak256(
            abi.encode(delegationManager.STAKER_DELEGATION_TYPEHASH(), staker, operator, nonceBefore, type(uint256).max)
        );
        bytes32 digestHash = keccak256(abi.encodePacked("\x19\x01", delegationManager.domainSeparator(), structHash));

        bytes memory signature;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digestHash);
            // mess up the signature by flipping v's parity
            v = (v == 27 ? 28 : 27);
            signature = abi.encodePacked(r, s, v);
        }

        vm.expectRevert(
            bytes("EIP1271SignatureUtils.checkSignature_EIP1271: ERC1271 signature verification failed")
        );
        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils.SignatureWithExpiry({
            signature: signature,
            expiry: type(uint256).max
        });
        delegationManager.delegateToBySignature(staker, operator, signatureWithExpiry, signatureWithExpiry, bytes32(0));
    }

    /// @notice  tries delegating using a wallet that does not comply with EIP 1271
    function testDelegateToBySignature_WithContractWallet_NonconformingWallet(
        address operator,
        uint96 mantaAmount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public fuzzedAddress(operator) {
        address staker = vm.addr(PRIVATE_KEY);

        // deploy non ERC1271-compliant wallet for staker to use
        vm.startPrank(staker);
        ERC1271MaliciousMock wallet = new ERC1271MaliciousMock();
        vm.stopPrank();
        staker = address(wallet);

        _registerOperatorAndDepositFromStaker(operator, staker, mantaAmount);

        vm.assume(staker != operator);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert();
        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils.SignatureWithExpiry({
            signature: signature,
            expiry: type(uint256).max
        });
        delegationManager.delegateToBySignature(staker, operator, signatureWithExpiry, signatureWithExpiry, bytes32(0));
    }

    /// @notice tests delegationManager to EigenLayer via an ECDSA signatures with invalid signature
    /// @param operator is the operator being delegated to.
    function testDelegateToByInvalidSignature(
        address operator,
        uint96 mantaAmount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public fuzzedAddress(operator) fuzzedAmounts(mantaAmount) {
        address staker = vm.addr(PRIVATE_KEY);
        _registerOperatorAndDepositFromStaker(operator, staker, mantaAmount);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert();
        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry = ISignatureUtils.SignatureWithExpiry({
            signature: signature,
            expiry: type(uint256).max
        });
        delegationManager.delegateToBySignature(staker, operator, signatureWithExpiry, signatureWithExpiry, bytes32(0));
    }

    /// @notice This function tests to ensure that a delegationManager contract
    ///         cannot be intitialized multiple times
    function testCannotInitMultipleTimesDelegation() public cannotReinit {
        //delegationManager has already been initialized in the Deployer test contract
        delegationManager.initialize(
            address(this),
            mantaLayerPauserReg,
            0,
            minWithdrawalDelayBlocks,
            initializeStrategiesToSetDelayBlocks,
            initializeWithdrawalDelayBlocks
        );
    }

    /// @notice This function tests to ensure that a you can't register as a delegate multiple times
    /// @param operator is the operator being delegated to.
    function testRegisterAsOperatorMultipleTimes(address operator) public fuzzedAddress(operator) {
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            earningsReceiver: operator,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });
        _testRegisterAsOperator(operator, operatorDetails);
        vm.expectRevert(bytes("DelegationManager.registerAsOperator: caller is already actively delegated"));
        _testRegisterAsOperator(operator, operatorDetails);
    }

    /// @notice This function tests to ensure that a staker cannot delegate to an unregistered operator
    /// @param delegate is the unregistered operator
    function testDelegationToUnregisteredDelegate(address delegate) public fuzzedAddress(delegate) {
        //deposit into 1 strategy for getOperatorAddress(1), who is delegating to the unregistered operator
        _testDepositStrategies(getOperatorAddress(1), 1e18, 1);
        _testDepositManta(getOperatorAddress(1), 1e18);

        vm.expectRevert(bytes("DelegationManager.delegateTo: operator is not registered in EigenLayer"));
        vm.startPrank(getOperatorAddress(1));
        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry;
        delegationManager.delegateTo(delegate, signatureWithExpiry, bytes32(0));
        vm.stopPrank();
    }

    /// @notice This function tests to ensure that a delegationManager contract
    ///         cannot be intitialized multiple times, test with different caller addresses
    function testCannotInitMultipleTimesDelegation(address _attacker) public {
        vm.assume(_attacker != address(delegationManagerProxyAdmin));
        //delegationManager has already been initialized in the Deployer test contract
        vm.prank(_attacker);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        delegationManager.initialize(
            _attacker,
            mantaLayerPauserReg,
            0,
            0, // minWithdrawalDelayBLocks
            initializeStrategiesToSetDelayBlocks,
            initializeWithdrawalDelayBlocks
        );
    }

    /// @notice This function tests to ensure that an address can only call registerAsOperator() once
    function testCannotRegisterAsOperatorTwice(
        address _operator,
        address _dt
    ) public fuzzedAddress(_operator) fuzzedAddress(_dt) {
        vm.assume(_dt != address(0));
        vm.startPrank(_operator);
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            earningsReceiver: msg.sender,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });
        string memory emptyStringForMetadataURI;
        delegationManager.registerAsOperator(operatorDetails, emptyStringForMetadataURI);
        vm.expectRevert("DelegationManager.registerAsOperator: caller is already actively delegated");
        delegationManager.registerAsOperator(operatorDetails, emptyStringForMetadataURI);
        vm.stopPrank();
    }

    /// @notice this function checks that you can only delegate to an address that is already registered.
    function testDelegateToInvalidOperator(
        address _staker,
        address _unregisteredoperator
    ) public fuzzedAddress(_staker) {
        vm.startPrank(_staker);
        vm.expectRevert(bytes("DelegationManager.delegateTo: operator is not registered in EigenLayer"));
        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry;
        delegationManager.delegateTo(_unregisteredoperator, signatureWithExpiry, bytes32(0));
        vm.expectRevert(bytes("DelegationManager.delegateTo: operator is not registered in EigenLayer"));
        delegationManager.delegateTo(_staker, signatureWithExpiry, bytes32(0));
        vm.stopPrank();
    }

    function testUndelegate_SigP_Version(address _operator, address _staker, address _dt) public {
        vm.assume(_operator != address(0));
        vm.assume(_staker != address(0));
        vm.assume(_operator != _staker);
        vm.assume(_dt != address(0));
        vm.assume(_operator != address(delegationManagerProxyAdmin));
        vm.assume(_staker != address(delegationManagerProxyAdmin));

        // setup delegationManager
        vm.prank(_operator);
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            earningsReceiver: _dt,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });
        string memory emptyStringForMetadataURI;
        delegationManager.registerAsOperator(operatorDetails, emptyStringForMetadataURI);
        vm.prank(_staker);
        ISignatureUtils.SignatureWithExpiry memory signatureWithExpiry;
        delegationManager.delegateTo(_operator, signatureWithExpiry, bytes32(0));

        // operators cannot undelegate from themselves
        vm.prank(_operator);
        vm.expectRevert(bytes("DelegationManager.undelegate: operators cannot be undelegated"));
        delegationManager.undelegate(_operator);

        // assert still delegated
        assertTrue(delegationManager.isDelegated(_staker));
        assertTrue(delegationManager.isOperator(_operator));

        // _staker *can* undelegate themselves
        vm.prank(_staker);
        delegationManager.undelegate(_staker);

        // assert undelegated
        assertTrue(!delegationManager.isDelegated(_staker));
        assertTrue(delegationManager.isOperator(_operator));
    }

    function _testRegisterAdditionalOperator(uint256 index) internal {
        address sender = getOperatorAddress(index);

        //register as WMANTA operator
        uint256 mantaToDeposit = 1e10;
        _testDepositManta(sender, mantaToDeposit);
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            earningsReceiver: sender,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });
        _testRegisterAsOperator(sender, operatorDetails);
        vm.startPrank(sender);

        vm.stopPrank();
    }

    // registers the operator if they are not already registered, and deposits "WMANTA" on behalf of the staker.
    function _registerOperatorAndDepositFromStaker(
        address operator,
        address staker,
        uint96 mantaAmount
    ) internal {
        vm.assume(staker != operator);

        // if first deposit amount to base strategy is too small, it will revert. ignore that case here.
        vm.assume(mantaAmount >= 1 && mantaAmount <= 1e18);

        if (!delegationManager.isOperator(operator)) {
            IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
                earningsReceiver: operator,
                delegationApprover: address(0),
                stakerOptOutWindowBlocks: 0
            });
            _testRegisterAsOperator(operator, operatorDetails);
        }

        //making additional deposits to the strategies
        assertTrue(!delegationManager.isDelegated(staker) == true, "testDelegation: staker is not delegate");
        _testDepositManta(staker, mantaAmount);
    }
}

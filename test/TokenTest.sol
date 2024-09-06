// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import "@test/TestERC20Helper.t.sol";
//import "@test/TokenTest_2.sol";

contract TokenTest is Script, Test {
    address public constant EOAowner = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
    address public constant EARNINGS_RECEIVER = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    using SafeERC20 for IERC20;

    TestERC20Helper public erc20TestToken;

    function test_TestERC20Helper() public {
        vm.startPrank(EOAowner);
        console.log("test_1 msg.sender:", msg.sender);

        string memory token_name = "TestToken";
        string memory token_symbol = "TTK";
        erc20TestToken = new TestERC20Helper("TestToken", "TTK", 12345678910 * 1e18, EOAowner);
        console.log("test_1 erc20TestToken:", address(erc20TestToken));

        vm.deal(address(EOAowner), 1111 ether);

        uint256 before_EOAowner_balance = erc20TestToken.balanceOf(EOAowner);
        console.log("test_1 before_EOAowner_balance :", before_EOAowner_balance);
        uint256 before_EARNINGS_RECEIVER_balance = erc20TestToken.balanceOf(EARNINGS_RECEIVER);
        console.log("test_1 before_EARNINGS_RECEIVER_balance :", before_EARNINGS_RECEIVER_balance);

        erc20TestToken.approve(EARNINGS_RECEIVER, 1 * 1e19);

        uint256 allowance = erc20TestToken.allowance(EOAowner, address(EARNINGS_RECEIVER));
        console.log("test_1 allowance :", allowance);

        erc20TestToken.transfer(EARNINGS_RECEIVER, 1 * 1e18);

        uint256 after_EOAowner_balance = erc20TestToken.balanceOf(EOAowner);
        console.log("test_1 after_EOAowner_balance :", after_EOAowner_balance);
        uint256 after_EARNINGS_RECEIVER_balance = erc20TestToken.balanceOf(EARNINGS_RECEIVER);
        console.log("test_1 after_EARNINGS_RECEIVER_balance :", after_EARNINGS_RECEIVER_balance);

        vm.stopPrank();
    }

    function test_IERC20() public {
        vm.startPrank(EOAowner);
        console.log("test_1 msg.sender:", msg.sender);

        string memory token_name = "TestToken";
        string memory token_symbol = "TTK";
        erc20TestToken = new TestERC20Helper("TestToken", "TTK", 12345678910 * 1e18, EOAowner);
        console.log("test_1 erc20TestToken:", address(erc20TestToken));

        IERC20 tokenAddressErc20 = IERC20(address(erc20TestToken));

        vm.deal(address(EOAowner), 1111 ether);

        uint256 before_EOAowner_balance = tokenAddressErc20.balanceOf(EOAowner);
        console.log("test_1 before_EOAowner_balance :", before_EOAowner_balance);
        uint256 before_EARNINGS_RECEIVER_balance = tokenAddressErc20.balanceOf(EARNINGS_RECEIVER);
        console.log("test_1 before_EARNINGS_RECEIVER_balance :", before_EARNINGS_RECEIVER_balance);

        tokenAddressErc20.approve(EARNINGS_RECEIVER, 1 * 1e19);

        uint256 allowance = tokenAddressErc20.allowance(EOAowner, address(EARNINGS_RECEIVER));
        console.log("test_1 allowance :", allowance);

        tokenAddressErc20.transfer(EARNINGS_RECEIVER, 1 * 1e18);

        uint256 after_EOAowner_balance = tokenAddressErc20.balanceOf(EOAowner);
        console.log("test_1 after_EOAowner_balance :", after_EOAowner_balance);
        uint256 after_EARNINGS_RECEIVER_balance = tokenAddressErc20.balanceOf(EARNINGS_RECEIVER);
        console.log("test_1 after_EARNINGS_RECEIVER_balance :", after_EARNINGS_RECEIVER_balance);

        vm.stopPrank();
    }

    function test_IERC20_safeTransferFrom() public {
        vm.startPrank(EOAowner);
        console.log("test_1 msg.sender:", msg.sender);
//        TokenTest_2 test2 = new TokenTest_2();
//        test2.test_change_msg_sender();
        console.log("test_1 msg.sender:", msg.sender);

        emit log_named_address("test_1 msg.sender:", msg.sender);

        string memory token_name = "TestToken";
        string memory token_symbol = "TTK";
        erc20TestToken = new TestERC20Helper("TestToken", "TTK", 12345678910 * 1e18, EOAowner);
        console.log("test_1 erc20TestToken:", address(erc20TestToken));

        IERC20 tokenAddressErc20 = IERC20(address(erc20TestToken));

        vm.deal(address(EOAowner), 1111 ether);

        uint256 before_EOAowner_balance = tokenAddressErc20.balanceOf(EOAowner);
        console.log("test_1 before_EOAowner_balance :", before_EOAowner_balance);
        uint256 before_EARNINGS_RECEIVER_balance = tokenAddressErc20.balanceOf(EARNINGS_RECEIVER);
        console.log("test_1 before_EARNINGS_RECEIVER_balance :", before_EARNINGS_RECEIVER_balance);
//        vm.prank(EOAowner);
        tokenAddressErc20.forceApprove(EOAowner, 1 * 1e19);
//        vm.prank(EOAowner);
        SafeERC20.safeTransferFrom(tokenAddressErc20, EOAowner, EARNINGS_RECEIVER, 1 * 1e18);
//        tokenAddressErc20.safeTransferFrom(EOAowner, EARNINGS_RECEIVER, 1 * 1e18);

        uint256 after_EOAowner_balance = tokenAddressErc20.balanceOf(EOAowner);
        console.log("test_1 after_EOAowner_balance :", after_EOAowner_balance);
        uint256 after_EARNINGS_RECEIVER_balance = tokenAddressErc20.balanceOf(EARNINGS_RECEIVER);
        console.log("test_1 after_EARNINGS_RECEIVER_balance :", after_EARNINGS_RECEIVER_balance);

        vm.stopPrank();
    }

    function test_IERC20_safeTransfer_1() public {
        vm.startPrank(EOAowner);
        console.log("test_1 msg.sender:", msg.sender);
//        TokenTest_2 test2 = new TokenTest_2();
//        test2.test_change_msg_sender();
        console.log("test_1 msg.sender:", msg.sender);

        emit log_named_address("test_1 msg.sender:", msg.sender);

        string memory token_name = "TestToken";
        string memory token_symbol = "TTK";
        erc20TestToken = new TestERC20Helper("TestToken", "TTK", 12345678910 * 1e18, EOAowner);
        console.log("test_1 erc20TestToken:", address(erc20TestToken));

        IERC20 tokenAddressErc20 = IERC20(address(erc20TestToken));

        vm.deal(address(EOAowner), 1111 ether);

        uint256 before_EOAowner_balance = tokenAddressErc20.balanceOf(EOAowner);
        console.log("test_1 before_EOAowner_balance :", before_EOAowner_balance);
        uint256 before_EARNINGS_RECEIVER_balance = tokenAddressErc20.balanceOf(EARNINGS_RECEIVER);
        console.log("test_1 before_EARNINGS_RECEIVER_balance :", before_EARNINGS_RECEIVER_balance);

        SafeERC20.forceApprove(tokenAddressErc20, EARNINGS_RECEIVER, 1 * 1e19);

        uint256 before_allowance = tokenAddressErc20.allowance(EOAowner, EARNINGS_RECEIVER);
        console.log("test_1 before_allowance :", before_allowance);

        SafeERC20.safeTransfer(tokenAddressErc20, EARNINGS_RECEIVER, 1 * 1e18);

        uint256 after_allowance = tokenAddressErc20.allowance(EOAowner, EARNINGS_RECEIVER);
        console.log("test_1 after_allowance :", after_allowance);
        uint256 after_EOAowner_balance = tokenAddressErc20.balanceOf(EOAowner);
        console.log("test_1 after_EOAowner_balance :", after_EOAowner_balance);
        uint256 after_EARNINGS_RECEIVER_balance = tokenAddressErc20.balanceOf(EARNINGS_RECEIVER);
        console.log("test_1 after_EARNINGS_RECEIVER_balance :", after_EARNINGS_RECEIVER_balance);

        vm.stopPrank();
    }
}

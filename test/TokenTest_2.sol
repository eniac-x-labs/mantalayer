// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

contract TokenTest_2 {

    function test_change_msg_sender() public {
        console.log("TokenTest_2 msg.sender:", msg.sender);


    }


}

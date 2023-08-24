// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/console2.sol";
import "forge-std/Test.sol";

import { RemoteOwnerCallEncoderWrapper } from "./RemoteOwnerCallEncoderWrapper.sol";
import { RemoteOwner } from "../../src/RemoteOwner.sol";

/// @dev See the "Writing Tests" section in the Foundry Book if this is your first time with Forge.
/// https://book.getfoundry.sh/forge/writing-tests
contract RemoteOwnerTest is Test {

    RemoteOwnerCallEncoderWrapper wrapper;

    address target;

    RemoteOwner remoteOwner;

    function setUp() public {
        wrapper = new RemoteOwnerCallEncoderWrapper();
        target = makeAddr("target");
        remoteOwner = RemoteOwner(payable(makeAddr("remoteOwner")));
        vm.etch(address(remoteOwner), "remoteOwner");
    }

    function testEncode() public {
        bytes memory recipientCalldata = abi.encodeWithSignature("getValue(uint256)", 42);
        bytes memory encodedData = wrapper.encodeCalldata(target, 0, recipientCalldata);
        assertEq(
            encodedData,
            abi.encodeWithSelector(RemoteOwner.execute.selector, target, 0, recipientCalldata)
        );
    }
}

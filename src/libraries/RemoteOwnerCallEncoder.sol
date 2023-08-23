// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RemoteOwner } from "../RemoteOwner.sol";

library RemoteOwnerCallEncoder {
    function encodeCalldata(address target, uint256 value, bytes memory data) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            RemoteOwner.execute.selector,
            target,
            value,
            data
        );
    }
}

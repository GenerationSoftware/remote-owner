// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Erc5164Account } from "../Erc5164Account.sol";

library Erc5164AccountCallEncoder {
    function encodeCalldata(address target, uint256 value, bytes calldata data) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            Erc5164Account.execute.selector,
            target,
            value,
            data
        );
    }
}

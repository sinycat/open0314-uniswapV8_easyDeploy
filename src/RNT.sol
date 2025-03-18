// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20Token.sol";

contract RNT is MyERC20Token {
    constructor() MyERC20Token("RNToken", "RNT") {
    }
} 
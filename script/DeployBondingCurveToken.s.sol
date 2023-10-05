// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {BondingCurveToken} from "../src/BondingCurveToken.sol";

contract DeployBondingCurveToken is Script {
    uint256 public DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 public deployerKey;

    // store token name and symbol as constants
    string public constant NAME = "BondingCurveToken";
    string public constant SYMBOL = "BCT";

    function run() external returns (BondingCurveToken) {
        console.log("test");
        if (block.chainid == 31337) {
            deployerKey = DEFAULT_ANVIL_PRIVATE_KEY;
        } else {
            deployerKey = vm.envUint("PRIVATE_KEY");
        }

        BondingCurveToken bondingCurveToken = new BondingCurveToken(NAME, SYMBOL);
        return bondingCurveToken;    
    }
}
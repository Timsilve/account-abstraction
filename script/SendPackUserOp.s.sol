// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    function generateSignedUserOP(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config
    ) public returns (PackedUserOperation memory) {
        // generate the unsigned data
        uint256 nonce = vm.getNonce(config.account);
        PackedUserOperation memory userOP = _generateUnsignedUserOP(
            callData,
            config.account,
            nonce
        );
        // get the user ophash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(
            userOP
        );
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // sign the hash
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }

        userOP.signature = abi.encodePacked(r, s, v);
        return userOP;
    }

    function _generateUnsignedUserOP(
        bytes memory callData,
        address sender,
        uint256 nonce
    ) internal pure returns (PackedUserOperation memory) {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityGasFee = 256;
        uint128 maxPerFeeGas = maxPriorityGasFee;
        return
            PackedUserOperation({
                sender: sender,
                nonce: nonce,
                initCode: hex"",
                callData: callData,
                accountGasLimits: bytes32(
                    (uint256(verificationGasLimit) << 128) |
                        uint256(callGasLimit)
                ),
                preVerificationGas: verificationGasLimit,
                gasFees: bytes32(
                    (uint256(maxPriorityGasFee) << 128) | uint256(maxPerFeeGas)
                ),
                paymasterAndData: hex"",
                signature: hex""
            });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {
        // HelperConfig helperConfig = new HelperConfig();
        // address dest = 0xeCf2834709f633FF5b4d0A7A1c330Ad325dEBc4C;
        // uint256 value = 0;
        // bytes functionData = abi.encodeWithSelector(
        //     IERC20.approve.selector,
        //     0x0866385B7D066148942cf53FC3fD96b47B924B28,
        //     1e18
        // );
        // bytes memory execute = abi.encodeWithSelector(
        //     MinimalAccount.execute.selector,
        //     dest,
        //     value,
        //     functionData
        // );
        // PackedUserOperation memory UserOp = generateSignedUserOP(
        //     executeData,
        //     helperconfig.getConfig(),
        //     address(minimalAccount)
        // );
        //  PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        // ops[0] = PackedUserOp;,
        // vm.startBroadcast();
        // IEntryPoint(helperconfig.getConfig().entryPoint).handleOps(ops, payable(dest));
        // vm.stopBroadcast();
    }

    function generateSignedUserOP(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public returns (PackedUserOperation memory) {
        // generate the unsigned data
        uint256 nonce = IEntryPoint(config.entryPoint).getNonce(
            minimalAccount,
            0
        );
        // uint256 nonce = vm.getNonce(minimalAccount);
        PackedUserOperation memory userOP = _generateUnsignedUserOP(
            callData,
            minimalAccount,
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

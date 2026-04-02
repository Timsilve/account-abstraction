// SPDX-License-Identifier:MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "../script/DeployMinimal.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "../script/SendPackUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TestMinimalAccount is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperconfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;
    address randomOwner = makeAddr("randomOwner");

    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        DeployMinimal deployMinimalAccount = new DeployMinimal();
        (helperconfig, minimalAccount) = deployMinimalAccount.deployMinimal();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testCanExecute() public {
        // arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );

        //act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        //assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNotOwnerCanExecute() public {
        //arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );

        vm.prank(randomOwner);
        vm.expectRevert(
            MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector
        );
        minimalAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public {
        // arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );

        PackedUserOperation memory PackedUserOp = sendPackedUserOp
            .generateSignedUserOP(
                executeData,
                helperconfig.getConfig(),
                address(minimalAccount)
            );
        bytes32 userOperationHash = IEntryPoint(
            helperconfig.getConfig().entryPoint
        ).getUserOpHash(PackedUserOp);

        //act
        address actualSigner = ECDSA.recover(
            userOperationHash.toEthSignedMessageHash(),
            PackedUserOp.signature
        );

        //assert
        assertEq(actualSigner, minimalAccount.owner());
    }

    function testValidateUserOp() public {
        // sign userOp
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );

        PackedUserOperation memory PackedUserOp = sendPackedUserOp
            .generateSignedUserOP(
                executeData,
                helperconfig.getConfig(),
                address(minimalAccount)
            );
        bytes32 userOperationHash = IEntryPoint(
            helperconfig.getConfig().entryPoint
        ).getUserOpHash(PackedUserOp);
        uint256 missingAccountFunds = 1e18;

        // validate userOp
        //act
        vm.prank(helperconfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(
            PackedUserOp,
            userOperationHash,
            missingAccountFunds
        );
        // assert the returns
        assertEq(validationData, 0);
    }

    function testEntryPointUserCanExecute() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );

        PackedUserOperation memory PackedUserOp = sendPackedUserOp
            .generateSignedUserOP(
                executeData,
                helperconfig.getConfig(),
                address(minimalAccount) //// hmmm
            );
        // bytes32 userOperationHash = IEntryPoint(
        //     helperconfig.getConfig().entryPoint
        // ).getUserOpHash(PackedUserOp);

        vm.deal(address(minimalAccount), 1e18);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = PackedUserOp;

        //act

        address defaultTxOriginAddress = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

        vm.startPrank(defaultTxOriginAddress);
        IEntryPoint(helperconfig.getConfig().entryPoint).handleOps(
            ops,
            payable(randomOwner)
        );
        vm.stopPrank();
        //assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}

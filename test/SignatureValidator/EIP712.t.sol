// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import { TestSignatureValidator } from "./Setup.t.sol";

contract TestEIP712 is TestSignatureValidator {
    uint8 public constant sigType = uint8(SignatureType.EIP712);

    function testEIP712WithDifferentSigner() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v, sigType);
        assertFalse(isValidSignature(vm.addr(userPrivateKey), digest, bytes(""), signature));
    }

    function testEIP712WithWrongHash() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v, sigType);
        bytes32 otherDigest = keccak256("other data other data");
        assertFalse(isValidSignature(vm.addr(userPrivateKey), otherDigest, bytes(""), signature));
    }

    function testEIP712WithWrongSignatureLength() public {
        uint256 r = 1;
        bytes memory signature = abi.encodePacked(r, sigType);
        // should have 33 bytes signature
        assertEq(signature.length, 33);
        vm.expectRevert("SignatureValidator#isValidSignature: length 65 or 97 required");
        isValidSignature(vm.addr(userPrivateKey), digest, bytes(""), signature);
    }

    function testEIP712() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v, sigType);
        assertTrue(isValidSignature(vm.addr(userPrivateKey), digest, bytes(""), signature));
    }
}

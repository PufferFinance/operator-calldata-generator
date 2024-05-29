// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { BN254 } from "eigenlayer-middleware/src/libraries/BN254.sol";
import { IBLSApkRegistry } from "eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import { ISignatureUtils } from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import { IRegistryCoordinatorExtended } from "../interface/IRegistryCoordinatorExtended.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { BaseScript } from "script/BaseScript.s.sol";

/**
 * forge script script/GenerateNodeOperatorSignatures.s.sol:GenerateNodeOperatorSignatures --rpc-url=$RPC_URL --ffi
 */
contract GenerateNodeOperatorSignatures is BaseScript {
    using BN254 for BN254.G1Point;
    using Strings for uint256;

    function run() public {
        address restakingOperatorContract = vm.envAddress("RESTAKING_OPERATOR_CONTRACT");
        address registryCoordinator = vm.envAddress("AVS_REGISTRY_COORDINATOR");

        address operatorAddress = vm.addr(vm.envUint("OPERATOR_ECDSA_SK"));

        // With ECDSA key, he sign the hash confirming that the operator wants to be registered to a certain restaking service
        (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) =
        _getOperatorSignature(
            vm.envUint("OPERATOR_ECDSA_SK"),
            restakingOperatorContract,
            vm.envAddress("AVS_SERVICE_MANAGER"),
            bytes32(keccak256(abi.encodePacked(block.timestamp, operatorAddress))),
            type(uint256).max
        );

        bytes memory hashCall = abi.encodeWithSelector(
            hex"d82752c8", // updateAVSRegistrationSignatureProof
            restakingOperatorContract,
            digestHash,
            operatorAddress
        );

        IBLSApkRegistry.PubkeyRegistrationParams memory params = _generateBlsPubkeyParams(vm.envUint("OPERATOR_BLS_SK"));
        // He signs with his BLS private key his pubkey to prove the BLS key ownership
        BN254.G1Point memory messageHash =
            IRegistryCoordinatorExtended(registryCoordinator).pubkeyRegistrationMessageHash(restakingOperatorContract);
        params.pubkeyRegistrationSignature = BN254.scalar_mul(messageHash, vm.envUint("OPERATOR_BLS_SK"));

        bytes memory calldataToRegister = abi.encodeWithSelector(
            hex"aba326d8", // callRegisterOperatorToAVS
            restakingOperatorContract,
            vm.envAddress("AVS_REGISTRY_COORDINATOR"),
            vm.envBytes("QUORUM"),
            vm.envString("SOCKET"), // Update to the correct value
            params,
            operatorSignature
        );

        console.log("Digest hash:");
        console.logBytes32(digestHash);
        console.log("--------------------");

        console.log("Store digest hash to PufferModuleManager calldata:");
        console.logBytes(hashCall);
        console.log("--------------------");

        console.log("RegisterOperatorToAVS calldata:");
        console.logBytes(calldataToRegister);
    }
}

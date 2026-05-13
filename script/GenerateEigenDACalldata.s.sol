// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { BN254 } from "eigenlayer-middleware/src/libraries/BN254.sol";
import { IBLSApkRegistry } from "eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import { ISignatureUtilsMixinTypes } from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtilsMixin.sol";
import { IRegistryCoordinatorExtended } from "../interface/IRegistryCoordinatorExtended.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { BaseScript } from "script/BaseScript.s.sol";

/**
 * EigenDA registration calldata generator. Uses the legacy AVSDirectory flow, routed through
 * PufferModuleManager.customExternalCall, because EigenDA has not migrated to AllocationManager
 * operator sets yet (`AllocationManager.getOperatorSetCount(eigenDA_SM) == 0` on mainnet as of
 * this writing).
 *
 * Flow:
 *   1. updateAVSRegistrationSignatureProof  — stores the EIP-1271 proof on the RestakingOperator
 *      so the AVSDirectory signature check via isValidSignature passes.
 *   2. customExternalCall(restakingOperator, registryCoordinator, registerOperator(...))
 *      — middleware RegistryCoordinator forwards to AVSDirectory.registerOperatorToAVS.
 *
 * Switch to the operator-sets script (selector 0xa06dee43) once EigenDA flips on operator sets.
 *
 * forge script script/GenerateEigenDACalldata.s.sol:GenerateEigenDACalldata --rpc-url=$RPC_URL --ffi
 */
contract GenerateEigenDACalldata is BaseScript {
    using BN254 for BN254.G1Point; 
    using Strings for uint256;

    function run() public {
        address restakingOperatorContract = vm.envAddress("RESTAKING_OPERATOR_CONTRACT");
        address registryCoordinator = vm.envAddress("AVS_REGISTRY_COORDINATOR");

        // ECDSA signature over the AVSDirectory digest; consumed via EIP-1271 on RestakingOperator.
        (bytes32 digestHash, ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry memory operatorSignature) =
        _getOperatorSignature(
            _ECDSA_SK,
            restakingOperatorContract,
            vm.envAddress("AVS_SERVICE_MANAGER"),
            bytes32(keccak256(abi.encodePacked(block.timestamp, restakingOperatorContract))),
            type(uint256).max
        );

        bytes memory hashCall = abi.encodeWithSelector(
            hex"d82752c8", // PufferModuleManager.updateAVSRegistrationSignatureProof(address,bytes32,address)
            restakingOperatorContract,
            digestHash,
            _ECDSA_ADDRESS
        );

        IBLSApkRegistry.PubkeyRegistrationParams memory params = _generateBlsPubkeyParams(vm.envUint("OPERATOR_BLS_SK"));
        // BLS pubkey ownership proof
        BN254.G1Point memory messageHash =
            IRegistryCoordinatorExtended(registryCoordinator).pubkeyRegistrationMessageHash(restakingOperatorContract);
        params.pubkeyRegistrationSignature = BN254.scalar_mul(messageHash, vm.envUint("OPERATOR_BLS_SK"));

        bytes memory innerRegisterCalldata = abi.encodeWithSelector(
            hex"a50857bf", // RegistryCoordinator.registerOperator(bytes,string,PubkeyRegistrationParams,SignatureWithSaltAndExpiry)
            vm.envBytes("QUORUM"),
            vm.envString("SOCKET"),
            params,
            operatorSignature
        );

        bytes memory calldataToRegister = abi.encodeWithSelector(
            hex"a6cee53d", // PufferModuleManager.customExternalCall(address,address,bytes)
            restakingOperatorContract,
            registryCoordinator,
            innerRegisterCalldata
        );

        console.log("Digest hash:");
        console.logBytes32(digestHash);
        console.log("--------------------");

        console.log("Store digest hash to PufferModuleManager calldata:");
        console.logBytes(hashCall);
        console.log("--------------------");

        console.log("RegisterOperatorToAVS calldata (via customExternalCall):");
        console.logBytes(calldataToRegister);
    }
}

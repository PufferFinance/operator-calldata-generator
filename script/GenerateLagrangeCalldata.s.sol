// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { console } from "forge-std/Script.sol";
import { BaseScript } from "script/BaseScript.s.sol";
import { BN254 } from "eigenlayer-middleware/src/libraries/BN254.sol";
import { IBLSApkRegistry } from "eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import { ISignatureUtils } from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// Interface for easier calldata generation
// This is for mainnet only, Holesky uses a different interface
interface ILagrangeService {
    function register(
        address signAddress,
        uint256[2][] memory blsPubKeys,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;
}

/**
 * forge script script/GenerateLagrangeCalldata.s.sol:GenerateLagrangeCalldata --rpc-url=$RPC_URL --ffi
 */
contract GenerateLagrangeCalldata is BaseScript {
    using BN254 for BN254.G1Point;
    using Strings for uint256;

    function run() public {
        address restakingOperatorContract = vm.envAddress("RESTAKING_OPERATOR_CONTRACT");
        // Lagrange https://lagrange-labs.gitbook.io/lagrange-v2-1/zk-coprocessor/avs-operators/registration
        // It is the same contract for both in Lagrange case
        address registryCoordinator = vm.envAddress("AVS_REGISTRY_COORDINATOR");
        address avs = vm.envAddress("AVS_SERVICE_MANAGER");

        address operatorAddress = vm.addr(vm.envUint("OPERATOR_ECDSA_SK"));

        // With ECDSA key, he sign the hash confirming that the operator wants to be registered to a certain restaking service
        (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) =
        _getOperatorSignature(
            vm.envUint("OPERATOR_ECDSA_SK"),
            restakingOperatorContract,
            avs,
            bytes32(keccak256(abi.encodePacked(block.timestamp, operatorAddress))),
            type(uint256).max
        );

        bytes memory hashCall = abi.encodeWithSelector(
            hex"d82752c8", // updateAVSRegistrationSignatureProof
            restakingOperatorContract,
            digestHash,
            operatorAddress
        );

        // Get the BLS pubkey params for EigenDA (they are used in eoracle, so we can just copy them to eoracle struct)
        IBLSApkRegistry.PubkeyRegistrationParams memory params = _generateBlsPubkeyParams(vm.envUint("OPERATOR_BLS_SK"));

        uint256[2][] memory blsPubKeys = new uint256[2][](1);
        blsPubKeys[0][0] = params.pubkeyG1.X;
        blsPubKeys[0][1] = params.pubkeyG1.Y;

        // Custom call to Lagrange
        bytes memory registrationCallData =
            abi.encodeCall(ILagrangeService.register, (operatorAddress, blsPubKeys, operatorSignature));

        bytes memory calldataToRegister = abi.encodeWithSelector(
            hex"a6cee53d", // pufferModuleManager.customExternalCall(address,address,bytes)
            restakingOperatorContract,
            registryCoordinator,
            registrationCallData
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

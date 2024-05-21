// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { console } from "forge-std/Script.sol";
import { BaseScript } from "script/BaseScript.s.sol";
import { BN254 } from "eigenlayer-middleware/src/libraries/BN254.sol";
import { IBLSApkRegistry } from "eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import { ISignatureUtils } from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import { IRegistryCoordinatorExtended } from "../interface/IRegistryCoordinatorExtended.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// Struct that eOracle uses in registration params
struct PubkeyRegistrationParams {
    BN254.G1Point pubkeyRegistrationSignature;
    BN254.G1Point chainValidatorSignature;
    BN254.G1Point pubkeyG1;
    BN254.G2Point pubkeyG2;
}

// Interface for easier calldata generation
interface IEORegistryCoordinator {
    function registerOperator(
        bytes calldata quorumNumbers,
        PubkeyRegistrationParams calldata params,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;
}

/**
 * forge script script/GenerateEoracleCalldata.s.sol:GenerateEoracleCalldata --rpc-url=$RPC_URL --ffi
 */
contract GenerateEoracleCalldata is BaseScript {
    using BN254 for BN254.G1Point;
    using Strings for uint256;

    PubkeyRegistrationParams eOracleRegistrationParams;

    function run() public {
        address restakingOperatorContract = vm.envAddress("RESTAKING_OPERATOR_CONTRACT");
        // EORACLE https://github.com/Eoracle/eoracle-middleware?tab=readme-ov-file
        address registryCoordinator = 0x757E6f572AfD8E111bD913d35314B5472C051cA8;
        address avs = 0x23221c5bB90C7c57ecc1E75513e2E4257673F0ef;
        
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

        // He signs with his BLS private key his pubkey to prove the BLS key ownership
        BN254.G1Point memory messageHash =
            IRegistryCoordinatorExtended(registryCoordinator).pubkeyRegistrationMessageHash(restakingOperatorContract);
        params.pubkeyRegistrationSignature = BN254.scalar_mul(messageHash, vm.envUint("OPERATOR_BLS_SK"));


        // Copy the params so that it satisfies eOracle interface
        eOracleRegistrationParams.pubkeyG1 = params.pubkeyG1;
        eOracleRegistrationParams.pubkeyG2 = params.pubkeyG2;
        eOracleRegistrationParams.pubkeyRegistrationSignature = params.pubkeyRegistrationSignature;
        // The last parameter is zero value

        // Quorum is hardcoded to 0
        bytes memory quorumNumbers = bytes(hex"00");

        bytes memory registrationCallData = abi.encodeCall(IEORegistryCoordinator.registerOperator, (
            quorumNumbers,
            eOracleRegistrationParams,
            operatorSignature
        ));

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
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { console } from "forge-std/Script.sol";
import { BaseScript } from "script/BaseScript.s.sol";
import { BN254 } from "eigenlayer-middleware/src/libraries/BN254.sol";
import { ISignatureUtils } from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// Interface for easier calldata generation
interface IWitnessChainRegistryCoordinator {
    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external; // 0x9926ee7d
}

interface IOperatorRegistry {
    // signedMessage = sign(calculateWatchtowerRegistrationMessageHash(..))
    function registerWatchtowerAsOperator(address watchtower, bytes32 salt, uint256 expiry, bytes memory signedMessage)
        external;

    function calculateWatchtowerRegistrationMessageHash(address operator, bytes32 salt, uint256 expiry)
        external
        view
        returns (bytes32);
}

/**
 * forge script script/GenerateWitnessChainCalldata.s.sol:GenerateWitnessChainCalldata --rpc-url=$RPC_URL --ffi
 */
contract GenerateWitnessChainCalldata is BaseScript {
    using BN254 for BN254.G1Point;
    using Strings for uint256;

    address restakingOperatorContract = vm.envAddress("RESTAKING_OPERATOR_CONTRACT");
    address operatorAddress = vm.addr(vm.envUint("OPERATOR_ECDSA_SK"));
    address avs = vm.envAddress("AVS_SERVICE_MANAGER");

    function run() public view {
        // With ECDSA key, he sign the hash confirming that the operator wants to be registered to a certain restaking service
        (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) =
        _getOperatorSignature(
            _ECDSA_SK,
            restakingOperatorContract,
            avs,
            bytes32(keccak256(abi.encodePacked(block.timestamp, restakingOperatorContract))),
            type(uint256).max
        );

        bytes memory hashCall = abi.encodeWithSelector(
            hex"d82752c8", // updateAVSRegistrationSignatureProof
            restakingOperatorContract,
            digestHash,
            _ECDSA_ADDRESS
        );

        // Watchtower registration calldata
        bytes32 msgHash = IOperatorRegistry(vm.envAddress("OPERATOR_REGISTRY"))
            .calculateWatchtowerRegistrationMessageHash(
            restakingOperatorContract,
            bytes32(keccak256(abi.encodePacked(block.timestamp + 1, operatorAddress))),
            type(uint256).max
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(vm.envUint("OPERATOR_ECDSA_SK"), msgHash);

        bytes memory signedMessage = abi.encodePacked(r, s, v);

        bytes memory registerWatchTOwerAsOperator = abi.encodeCall(
            IOperatorRegistry.registerWatchtowerAsOperator,
            (
                operatorAddress,
                bytes32(keccak256(abi.encodePacked(block.timestamp + 1, operatorAddress))),
                type(uint256).max,
                signedMessage
            )
        );

        bytes memory registraitonCd = abi.encodeWithSelector(
            hex"a6cee53d", // pufferModuleManager.customExternalCall(address,address,bytes)
            restakingOperatorContract,
            vm.envAddress("OPERATOR_REGISTRY"),
            registerWatchTOwerAsOperator
        );

        bytes memory registrationCallData = abi.encodeCall(
            IWitnessChainRegistryCoordinator.registerOperatorToAVS, (restakingOperatorContract, operatorSignature)
        );

        bytes memory calldataToRegister = abi.encodeWithSelector(
            hex"a6cee53d", // pufferModuleManager.customExternalCall(address,address,bytes)
            restakingOperatorContract,
            avs,
            registrationCallData
        );

        console.log("Store digest hash to PufferModuleManager calldata:");
        console.logBytes(hashCall);
        console.log("--------------------");

        console.log("Registration to AVS calldata:");
        console.logBytes(calldataToRegister);
        console.log("--------------------");

        console.log("registerWatchtowerAsOperator:");
        console.logBytes(registraitonCd);
    }
}

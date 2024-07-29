// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { BN254 } from "eigenlayer-middleware/src/libraries/BN254.sol";
import { ISignatureUtils } from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { BaseScript } from "script/BaseScript.s.sol";

interface IHyperLaneRegistryCoordinator {
    /// @notice Registers a new operator using a provided signature and signing key
    /// @param _operatorSignature Contains the operator's signature, salt, and expiry
    /// @param _signingKey The signing key to add to the operator's history
    function registerOperatorWithSignature(
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey
    ) external;
}

/**
 * forge script script/GenerateHyperlaneCalldata.s.sol:GenerateHyperlaneCalldata --rpc-url=$RPC_URL --ffi
 */
contract GenerateHyperlaneCalldata is BaseScript {
    using BN254 for BN254.G1Point;
    using Strings for uint256;

    function run() public view {
        address restakingOperatorContract = vm.envAddress("RESTAKING_OPERATOR_CONTRACT");
        address registryCoordinator = vm.envAddress("AVS_REGISTRY_COORDINATOR");
        address signingKeyAddress = vm.envAddress("ECDSA_SIGNING_KEY_ADDDRESS");

        // With ECDSA key, he sign the hash confirming that the operator wants to be registered to a certain restaking service
        (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) =
        _getOperatorSignature(
            _ECDSA_SK,
            restakingOperatorContract,
            vm.envAddress("AVS_SERVICE_MANAGER"),
            bytes32(keccak256(abi.encodePacked(block.timestamp, restakingOperatorContract))),
            type(uint256).max
        );

        bytes memory hashCall = abi.encodeWithSelector(
            hex"d82752c8", // updateAVSRegistrationSignatureProof
            restakingOperatorContract,
            digestHash,
            _ECDSA_ADDRESS
        );

        // custom registration calldata
        bytes memory registrationCallData = abi.encodeCall(
            IHyperLaneRegistryCoordinator.registerOperatorWithSignature, (operatorSignature, signingKeyAddress)
        );

        bytes memory calldataToRegister = abi.encodeWithSelector(
            hex"a6cee53d", // pufferModuleManager.customExternalCall(address,address,bytes)
            restakingOperatorContract,
            registryCoordinator,
            registrationCallData
        );

        console.log("Store digest hash to PufferModuleManager calldata:");
        console.logBytes(hashCall);
        console.log("--------------------");

        console.log("RegisterOperatorToAVS calldata:");
        console.logBytes(calldataToRegister);
    }
}

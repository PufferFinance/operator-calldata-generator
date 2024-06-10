// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { console } from "forge-std/Script.sol";
import { BaseScript } from "script/BaseScript.s.sol";
import { BN254 } from "eigenlayer-middleware/src/libraries/BN254.sol";
import { ISignatureUtils } from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// Interface for easier calldata generation
interface ILagrangeZKService {
    /// @notice A point on an elliptic curve
    /// @dev Used to represent an ECDSA public key
    struct PublicKey {
        uint256 x;
        uint256 y;
    }

    function registerOperator(
        PublicKey calldata publicKey,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;
}

/**
 * forge script script/GenerateLagrangeZKCalldata.s.sol:GenerateLagrangeZKCalldata --rpc-url=$RPC_URL --ffi
 */
contract GenerateLagrangeZKCalldata is BaseScript {
    using BN254 for BN254.G1Point;
    using Strings for uint256;

    function run() public view {
        address restakingOperatorContract = vm.envAddress("RESTAKING_OPERATOR_CONTRACT");
        // Lagrange https://lagrange-labs.gitbook.io/lagrange-v2-1/zk-coprocessor/avs-operators/registration
        // It is the same contract for both in Lagrange case
        address registryCoordinator = vm.envAddress("AVS_REGISTRY_COORDINATOR");
        address avs = vm.envAddress("AVS_SERVICE_MANAGER");

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

        ILagrangeZKService.PublicKey memory pubKey;
        pubKey.x = vm.envUint("ECDSA_X");
        pubKey.y = vm.envUint("ECDSA_Y");

        // Custom call to Lagrange
        bytes memory registrationCallData =
            abi.encodeCall(ILagrangeZKService.registerOperator, (pubKey, operatorSignature));

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

        console.log("RegisterOperatorToAVS GenerateLagrangeZKCalldata calldata:");
        console.logBytes(calldataToRegister);
        console.log("--------------------");
    }
}

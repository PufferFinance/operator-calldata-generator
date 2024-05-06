// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { BN254 } from "eigenlayer-middleware/src/libraries/BN254.sol";
import { IBLSApkRegistry } from "eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import { ISignatureUtils } from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import { IAVSDirectory } from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import { IRegistryCoordinatorExtended } from "../interface/IRegistryCoordinatorExtended.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * forge script script/GenerateNodeOperatorSignatures.s.sol:GenerateNodeOperatorSignatures --rpc-url=$RPC_URL
 */
contract GenerateNodeOperatorSignatures is Script {
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
            bytes32(abi.encodePacked(block.timestamp, operatorAddress)),
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

    // Generates bls pubkey params from a private key
    function _generateBlsPubkeyParams(uint256 privKey)
        internal
        returns (IBLSApkRegistry.PubkeyRegistrationParams memory)
    {
        IBLSApkRegistry.PubkeyRegistrationParams memory pubkey;
        pubkey.pubkeyG1 = BN254.generatorG1().scalar_mul(privKey);
        pubkey.pubkeyG2 = _mulGo(privKey);
        return pubkey;
    }

    function _mulGo(uint256 x) internal returns (BN254.G2Point memory g2Point) {
        string[] memory inputs = new string[](3);
        // inputs[0] = "./go2mul-mac"; // lib/eigenlayer-middleware/test/ffi/go/g2mul.go binary
        inputs[0] = "./go2mul"; // lib/eigenlayer-middleware/test/ffi/go/g2mul.go binary
        inputs[1] = x.toString();

        inputs[2] = "1";
        bytes memory res = vm.ffi(inputs);
        g2Point.X[1] = abi.decode(res, (uint256));

        inputs[2] = "2";
        res = vm.ffi(inputs);
        g2Point.X[0] = abi.decode(res, (uint256));

        inputs[2] = "3";
        res = vm.ffi(inputs);
        g2Point.Y[1] = abi.decode(res, (uint256));

        inputs[2] = "4";
        res = vm.ffi(inputs);
        g2Point.Y[0] = abi.decode(res, (uint256));
    }

    /**
     * @notice internal function for calculating a signature from the operator corresponding to `_operatorPrivateKey`, delegating them to
     * the `operator`, and expiring at `expiry`.
     */
    function _getOperatorSignature(
        uint256 _operatorPrivateKey,
        address operator,
        address avs,
        bytes32 salt,
        uint256 expiry
    ) internal view returns (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) {
        operatorSignature.expiry = expiry;
        operatorSignature.salt = salt;
        {
            digestHash = IAVSDirectory(vm.envAddress("AVS_DIRECTORY")).calculateOperatorAVSRegistrationDigestHash(
                operator, avs, salt, expiry
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_operatorPrivateKey, digestHash);
            operatorSignature.signature = abi.encodePacked(r, s, v);
        }
        return (digestHash, operatorSignature);
    }
}

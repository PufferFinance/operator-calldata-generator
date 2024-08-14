// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { console } from "forge-std/Script.sol";
import { ISignatureUtils } from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import { BaseScript } from "script/BaseScript.s.sol";

interface IChainbaseRegistryCoordinator {
    /**
     * @notice Register an operator with the AVS. Forwards call to EigenLayer' AVSDirectory.
     * @param operatorSignature The signature, salt, and expiry of the operator's signature.
     */
    function registerOperator(ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) external;
}

/**
 * forge script script/GenerateChainbaseCalldata.s.sol:GenerateChainbaseCalldata --rpc-url=$RPC_URL --ffi
 */
contract GenerateChainbaseCalldata is BaseScript {
    function run() public view {
        address restakingOperatorContract = vm.envAddress("RESTAKING_OPERATOR_CONTRACT");
        address avsRegistryCoordinator = vm.envAddress("AVS_REGISTRY_COORDINATOR");
        address avsServiceManager = vm.envAddress("AVS_SERVICE_MANAGER");

        (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) =
        _getOperatorSignature(
            _ECDSA_SK,
            restakingOperatorContract,
            avsServiceManager,
            bytes32(keccak256(abi.encodePacked(block.timestamp, restakingOperatorContract))),
            type(uint256).max
        );

        bytes memory hashCall = abi.encodeWithSelector(
            hex"d82752c8", // PufferModuleManager.updateAVSRegistrationSignatureProof
            restakingOperatorContract,
            digestHash,
            _ECDSA_ADDRESS
        );

        // custom registration calldata
        bytes memory registrationCallData =
            abi.encodeCall(IChainbaseRegistryCoordinator.registerOperator, (operatorSignature));

        bytes memory calldataToRegister = abi.encodeWithSelector(
            hex"a6cee53d", // pufferModuleManager.customExternalCall(address,address,bytes)
            restakingOperatorContract,
            avsRegistryCoordinator,
            registrationCallData
        );

        console.log("Store digest hash to PufferModuleManager calldata:");
        console.logBytes(hashCall);
        console.log("--------------------");

        console.log("RegisterOperatorToAVS calldata:");
        console.logBytes(calldataToRegister);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { console } from "forge-std/Script.sol";
import { ISignatureUtils } from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import { BaseScript } from "script/BaseScript.s.sol";

interface IUniFiAVSManager {
    /**
     * @notice Register an operator with the AVS.
     * @param operatorSignature The signature, salt, and expiry of the operator's signature.
     */
    function registerOperator(ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) external;
}

/**
 * forge script script/ GenerateUniFiCalldata.s.sol: GenerateUniFiCalldata --rpc-url=$RPC_URL --ffi
 */
contract  GenerateUniFiCalldata is BaseScript {
    function run() public view {
        address restakingOperatorContract = vm.envAddress("RESTAKING_OPERATOR_CONTRACT");
        address avsManagerAddress = vm.envAddress("AVS_MANAGER_ADDRESS");

        (bytes32 digestHash, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) =
        _getOperatorSignature(
            _ECDSA_SK,
            restakingOperatorContract,
            avsManagerAddress,
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
            abi.encodeCall(IUniFiAVSManager.registerOperator, (operatorSignature));

        bytes memory calldataToRegister = abi.encodeWithSelector(
            hex"a6cee53d", // pufferModuleManager.customExternalCall(address,address,bytes)
            restakingOperatorContract,
            avsManagerAddress,
            registrationCallData
        );

        console.log("Store digest hash to PufferModuleManager calldata:");
        console.logBytes(hashCall);
        console.log("--------------------");

        console.log("RegisterOperatorToAVS calldata:");
        console.logBytes(calldataToRegister);
    }
}
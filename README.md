## Node operator signature generator

Requirements:
https://book.getfoundry.sh/getting-started/installation

## Usage

Step 1. 
`forge install`

Step 2: 
Update values in the `.env`

Step 3: If the AVS uses the standard interface that EigenDA uses:
```shell
forge script script/GenerateNodeOperatorSignatures.s.sol:GenerateNodeOperatorSignatures --rpc-url=$RPC_URL --ffi
```
eOracle:
```
forge script script/GenerateEoracleCalldata.s.sol:GenerateEoracleCalldata --rpc-url=$RPC_URL --ffi
```
Lagrange:
```
forge script script/GenerateLagrangeCalldata.s.sol:GenerateLagrangeCalldata --rpc-url=$RPC_URL --ffi
```

Output example:
```bash
forge script script/GenerateNodeOperatorSignatures.s.sol:GenerateNodeOperatorSignatures --rpc-url=$RPC_URL --ffi
[⠢] Compiling...
No files changed, compilation skipped
Script ran successfully.

== Logs ==
  Digest hash:
  0xb78498d6632cb247dd10ee5b8f4aaa3151687a42603bee587681f700e70b9882
  --------------------
  Store digest hash to PufferModuleManager calldata:
  0xd82752c80000000000000000000000007037e66dbf098a78492f238ac46fd4af034f487bb78498d6632cb247dd10ee5b8f4aaa3151687a42603bee587681f700e70b988200000000000000000000000085ea121c6f44c604e5fc51ef80ed72b65fe51cfb
  --------------------
  RegisterOperatorToAVS calldata:
  0xaba326d80000000000000000000000007037e66dbf098a78492f238ac46fd4af034f487b00000000000000000000000053012c69a189cfa2d9d29eb6f19b32e0a2ea349000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e021728ea86e8f2a3a818db291a0040ab33a6b8017a44712d16e1fe1bb7aca68c62a109610c2bc4f7558d9f6afffe54d4bdbf65eadae37c4466d24ac0e6c6542b30018ff600bf019764bddb3f7fbdeb6a4ce9565094e84b63efacd53078f24bbae122c3ef68f4e9d017ed4239036abf090b8c64060e9000a9635d07e4a169db3a701af954ab0bc4eb97eb0a9c2b96e562c9c77b03f5738f81aba0686723912440c0069cb0fe625789d337dac78686a223b1bbc5b1a729999fc2e77035d9f5f112e0fb88da5ce344ade7963d56e01aec12b23cb346e73c32a3eb2775d755c313294033248453df37e215ba55503a7737f8cdabb7e75bc1cb9a6a690636e42ac75d5000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001732302e36342e31362e32393a33323030353b33323030340000000000000000000000000000000000000000000000000000000000000000000000000000000060aaaabbccbbaabb00000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000412bcd8691bd9879f138042a30936e69c798cdfcffde8438475f7b141216bf10da608ccd3eae84c708982571297a01800b0840d2567e9584d9929c6d98b87507121b00000000000000000000000000000000000000000000000000000000000000
```

## Troubleshooting

### Note: Some of the AVSs use a different interface for registration for Mainnet/Holesky

### Permission issue
```bash
failed to execute command cd "/home/puffer-signature-generator" && "./go2mul" Permission denied (os error 13)
```
or something similar, do `chmod +x go2mul` 

### Using Mac instead of Linux
Change `inputs[0] = "./go2mul";` to `inputs[0] = "./go2mul-mac";` in the script/GenerateNodeOperatorSignatures.s.sol
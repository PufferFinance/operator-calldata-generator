## Node operator signature generator

Requirements:
https://book.getfoundry.sh/getting-started/installation

## Usage

Update values in the `.env` and run 
```shell
forge script script/GenerateNodeOperatorSignatures.s.sol:GenerateNodeOperatorSignatures --rpc-url=$HOLESKY_RPC_URL --ffi
```

## Troubleshooting
If the script reverts with 
```bash
failed to execute command cd "/home/puffer-signature-generator" && "./go2mul" Permission denied (os error 13)
```
or something similar, do `chmod +x go2mul` 
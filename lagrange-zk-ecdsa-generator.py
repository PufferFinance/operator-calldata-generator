import subprocess
import re
import os
from ecdsa import SigningKey, SECP256k1

# remove the existing keystore if it exists
if os.path.exists("lagrange-zk/avs"):
    os.remove("lagrange-zk/avs")
    #nothing

# Sanity checks
# Check if .env already contains "x coordinate" and LAGRANGE_OPERATOR_KEYSTORE_PW
with open(".env", "r") as file:
    if "ECDSA_X" in file.read():
        print("Error: .env file already contains x coordinate. Please delete LAGRANGE_ECDSA_SK,ECDSA_X,ECDSA_Y from the .env")
        exit(1)

    file.seek(0)  # Reset file pointer to the beginning

    if "LAGRANGE_OPERATOR_KEYSTORE_PW" in file.read():
        file.seek(0)  # Reset file pointer to the beginning
        for line in file:
            if line.startswith("LAGRANGE_OPERATOR_KEYSTORE_PW"):
                keystore_pw = line.split("=")[1].strip()
                break
        else:
            print("Error: LAGRANGE_OPERATOR_KEYSTORE_PW not found in .env file.")
            exit(1)
    else:
        print("Error: LAGRANGE_OPERATOR_KEYSTORE_PW not found in .env file.")
        exit(1)

# Execute the command to retrieve the private key
command = "cast wallet new"
result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)

# Parse the output to extract the private key
private_key_match = re.search(r"Private key: (0x[0-9a-fA-F]+)", result.stdout)
if private_key_match:
    private_key_hex = private_key_match.group(1)
else:
    print("Error: Private key not found in the command output.")
    exit(1)

# Convert the private key from hexadecimal to bytes
private_key_bytes = bytes.fromhex(private_key_hex[2:])  # Exclude the '0x' prefix and convert to bytes

# Create the signing key object
signing_key = SigningKey.from_string(private_key_bytes, curve=SECP256k1)

# Get the corresponding public key
public_key = signing_key.verifying_key

# Extract the x and y coordinates
x = public_key.pubkey.point.x()
y = public_key.pubkey.point.y()

# Open a file in append mode and write the coordinates to it
with open(".env", "a") as file:
    file.write(f"\n")
    file.write(f"LAGRANGE_ECDSA_SK={private_key_hex}")
    file.write(f"\n")
    file.write(f"ECDSA_X={x}")
    file.write(f"\n")
    file.write(f"ECDSA_Y={y}")

print("Please back up this ECDSA SK:")
print("LAGRANGE_ECDSA_SK", private_key_hex)

command = f"cast wallet import -k lagrange-zk --private-key={private_key_hex} avs --unsafe-password={keystore_pw}"
result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
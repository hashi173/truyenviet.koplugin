import base64
import string

enc = base64.b64decode("VUJZXFxcaUZWX0RrCx0AAVRCWV1VXGheEQ0GKwE=")

# Try single byte XOR
for key in range(256):
    dec = bytes([b ^ key for b in enc])
    # check if mostly printable
    printable_count = sum(1 for c in dec if chr(c) in string.printable and c >= 32)
    if printable_count >= len(dec) - 4:
        try:
            s = dec.decode('ascii', errors='ignore')
            print(f"Key XOR {key:02X} ({key}): {s}")
        except Exception:
            pass

# Try multi-byte XOR or Vigenere?
# Let's check if the first few bytes have a pattern.
# For example, if the decrypted string starts with "1780" or similar digit:
# Let's print the XOR key for each byte assuming the target starts with "1780"
target_prefix = "17809"
if len(enc) >= len(target_prefix):
    keys = [enc[i] ^ ord(target_prefix[i]) for i in range(len(target_prefix))]
    print("XOR keys assuming prefix '17809':", keys)

# Let's print the XOR key assuming target starts with "uploads" or similar
# Actually, the base path is already "uploads/2026-06-08/", so the obfuscated part is only the filename.
# If the filename starts with "17809" (which is the timestamp 1780936573046 or similar)

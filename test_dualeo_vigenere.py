import base64

enc = base64.b64decode("VUJZXFxcaUZWX0RrCx0AAVRCWV1VXGheEQ0GKwE=")
key = "dualeo".encode('ascii')

dec = []
for i in range(len(enc)):
    dec_byte = enc[i] ^ key[i % len(key)]
    dec.append(dec_byte)

dec_bytes = bytes(dec)
print("Decrypted bytes:", list(dec_bytes))
print("Decrypted string:", dec_bytes.decode('utf-8', errors='ignore'))

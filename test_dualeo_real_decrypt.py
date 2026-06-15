import base64

string = "VUJZXFxcaUZWX0RrCx0AAVRCWV1VXGheEQ0GKwE"

# Function d in JS: s + '==='.slice((s.length+3)%4)
def pad_base64(s):
    return s + '=' * ((4 - len(s) % 4) % 4)

# Function c in JS: b[i % b.length]
salt = b"dualeo_salt_2025"

# Replace - with + and _ with /
clean_str = string.replace('-', '+').replace('_', '/')
padded = pad_base64(clean_str)

enc = base64.b64decode(padded)

dec = []
for i in range(len(enc)):
    dec.append(enc[i] ^ salt[i % len(salt)])
    
dec_bytes = bytes(dec)
print("Decrypted filename:", dec_bytes.decode('utf-8', errors='ignore'))

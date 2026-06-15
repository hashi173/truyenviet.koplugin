import base64

string = "VUJZXFxcaUZWX0RrCx0AAVRCWV1VXGheEQ0GKwE="

try:
    decoded = base64.b64decode(string)
    print("Decoded length:", len(decoded))
    print("Decoded bytes:", list(decoded))
    # print as hex
    print("Decoded hex:", decoded.hex())
    # print as ascii where possible
    print("Decoded string (ASCII):", decoded.decode('ascii', errors='replace'))
except Exception as e:
    print("Error:", e)

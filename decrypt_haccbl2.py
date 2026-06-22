import re
import json
import base64
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

html = open('haccbl_chap1.html', encoding='utf-8').read()
match = re.search(r'var InitMangaEncryptedChapter = (\{.*?\});', html)
if match:
    data = json.loads(match.group(1))
    key_match = re.search(r'decryption_key\":\"([^\"]+)\"', html)
    if key_match:
        key_str = base64.b64decode(key_match.group(1))
        salt = bytes.fromhex(data['salt'])
        iv = bytes.fromhex(data['iv'])
        ciphertext = base64.b64decode(data['ciphertext'])
        kdf = PBKDF2HMAC(algorithm=hashes.SHA512(), length=32, salt=salt, iterations=999, backend=default_backend())
        key = kdf.derive(key_str)
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        decryptor = cipher.decryptor()
        decrypted = decryptor.update(ciphertext) + decryptor.finalize()
        imgs = re.findall(r'<img[^>]*>', decrypted.decode('utf-8', errors='ignore'))
        print('\n'.join(imgs[:5]))

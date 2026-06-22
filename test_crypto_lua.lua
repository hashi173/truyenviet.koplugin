local ffi = require("ffi")

ffi.cdef[[
typedef struct evp_md_st EVP_MD;
typedef struct evp_cipher_st EVP_CIPHER;

const EVP_MD *EVP_sha512(void);
int PKCS5_PBKDF2_HMAC(const char *pass, int passlen,
                      const unsigned char *salt, int saltlen, int iter,
                      const EVP_MD *digest,
                      int keylen, unsigned char *out);
const EVP_CIPHER *EVP_aes_256_cbc(void);

typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX;
EVP_CIPHER_CTX *EVP_CIPHER_CTX_new(void);
void EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *c);
int EVP_DecryptInit_ex(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *cipher, void *impl,
                       const unsigned char *key, const unsigned char *iv);
int EVP_DecryptUpdate(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl,
                      const unsigned char *in_buf, int inl);
int EVP_DecryptFinal_ex(EVP_CIPHER_CTX *ctx, unsigned char *outm, int *outl);
]]

local libcrypto = ffi.load("crypto")

local function hex2bin(hexstr)
    return (hexstr:gsub('..', function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

local function base64_decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local keyStrBase64 = "OENBNkU0NUYxQzREMEFDQg=="
local keyStr = base64_decode(keyStrBase64)

local ciphertext_b64 = "6OM8MV4/QcwETs10expZgWRxSPeRYsXBVWnpOT83M8Amnz2yuaJN7WASrBTvKJDoXDWhrR54Ct+Rh/kBUBfeJ71IFB99quGgjH6a2SPb880Ie3AGFXhCAdEkETQtvva3dTR5WmP8/9ir65mB7mFmPX5Uj1p1wK28CUSY6BTzSnH3VQcgCjJn2e+IepdLT28BPjBCVO7Y/vWz7/YckB3W7Bl8V3tfUNxg39j9ym+yuMdR0DIzwl07qMQm+0srifkMu8HyFwRGY/Gfw7Ch7BwuACiPzoQCP4mWQs1NCXYf9LplhGShMRIpqRJq5q6LPMcPQTzbfWK3ZrNWvXjME2J17LjXDP7BPCK8RIkzvLDlFx9FMozaKDn+aydteeNbPb6FcAfc1hVTcZLG2iC78bjN+Z2pxa9ZyiBByRlgDXj7/l7qa1xMN2CTLu3MQrhfEQQAjyonQQtItfU/ueqSFtlqfuUYuacRQ5l2o0APYcEckSIbiLRvBB5KumaZvW4tst6ktjgqYc9QWlh0vkds9jujUZKFOqaNMZvrydmn3VmTZKsjBXtJKaVrH/Cn4W+QRJCU8sLKK7i+FNrx2F8X0bQXfVuiP8jVz6S1TY5b6JI/liEtzYGdpNi1/rwTJagz2e67gA2KLRQScq/XNaarIaHKaN3SRvdWSXSijF1NAWPjVSCry0vjBSf1hw1BJ0UG1zEv6yoKnn2NtYgkil5IRwUF2Ui2Skl56ZkUJluWdXtxQYerkwAk3NT6Zt1EYn+jM8VxT1N8PWRXP5TOU9OHHIV8nl2F1EcGaIlYzv8Ka3l1ILUgZNLNfHYViRp16PNtweDadpH53uzO42Gw7FP2Bjvi5f7tPZy0y0gPooW7ot9PGMW1XDrcotwh4ZlXa+IQVEKqKWrC+wY6X65s1q5/JTlNY4oR707MKRw9JZkGWYsgSwDEIBJxoCArf2s56BoX1GbgDQ8qEHfnWAONDfUmdaSLw70wEcl6hqaXU6ei8ibJByPL2vrQtNsD6zYToPGakOJiSs5xaV95m4raWAHKrICspq4yOZbr38XLUguabhz6vOV+/WqEKamP+H8opCKplcQ3MqK1ygkGnPDYHoyX4YjsE/nLVhvwrx0yAJVrmh6HNgJkoA0ayK6MGP2EEVyyQe3jedPJ3gJeyVlZrVjeVi3jQO+kIM9/1ROptIwM4ofnEj5iynYDeoD1//mjJJ47yPORGD/eS12EBW6rhxgRlIdrZJTm1qrMomNLq/4X4VEJyTf7PDmFgLn2+s47sgreoXTYzU5ltH8HD9Wg70m1flBIi1PP6XbHHSkrFWcJWjUwI7TyxoqeWRpBA9rp7GNelBMZBMdjUEBr9Wayajhq/26EWU0UUNkUPjGq+caZvhEpZHKgWHeFEpbKLGOfwIsWXdUF/ZQ/+nrer6esVl/DcOXC+wNmgMSL3oW1ym4b0ePpMtDCb41YgwnQ3hNg6WNJS4okExAddciHcvxaJvZP5cLtfQ=="
local ciphertext = base64_decode(ciphertext_b64)
local saltHex = "c1c6ad39eae7cf239bff283a5fa324fe2e867aa2d5887c471376acb10d78245054a37fb6720255050d8781d1ed5894182184de1a335233ce63029297432a1c13188e6ee60e55663f01fb56dec5ee117c84ce939e99a1741bbe240db8f198ce0f2f7ccd84cf9cb04522284c508de7d88a3efac7060a8a02e8235269ec5a85ee7776701af97712f1b363aef5b27343cd2c4018588f9316cb56e6dca3ffa5ecc6f78ab99c0b4208dbd4ac798d9a4371b82dc334b197f9d9c2c61033c905273c1fb82611518c3ff8cf2517fa129562ba8bb83adb593e5f241691e19a5d1c307973ec2f54990506058c41d6f98b529a7f6d7919727504d90952c2c03244291bce18a4"
local ivHex = "0ec780ebd4cf7b5f6e401dd19903d681"

local salt = hex2bin(saltHex)
local iv = hex2bin(ivHex)

local derivedKey = ffi.new("unsigned char[32]")
local res = libcrypto.PKCS5_PBKDF2_HMAC(keyStr, #keyStr, salt, #salt, 999, libcrypto.EVP_sha512(), 32, derivedKey)
if res ~= 1 then
    error("PBKDF2 failed")
end

local ctx = libcrypto.EVP_CIPHER_CTX_new()
libcrypto.EVP_DecryptInit_ex(ctx, libcrypto.EVP_aes_256_cbc(), nil, derivedKey, iv)

local out = ffi.new("unsigned char[?]", #ciphertext + 32)
local outl = ffi.new("int[1]")
local outl2 = ffi.new("int[1]")

libcrypto.EVP_DecryptUpdate(ctx, out, outl, ciphertext, #ciphertext)
local res = libcrypto.EVP_DecryptFinal_ex(ctx, out + outl[0], outl2)
if res ~= 1 then
    error("DecryptFinal failed (padding error?)")
end

local total_len = outl[0] + outl2[0]
local decrypted_text = ffi.string(out, total_len)

print("Decrypted successfully in Lua:")
print(decrypted_text:sub(1, 200))

libcrypto.EVP_CIPHER_CTX_free(ctx)

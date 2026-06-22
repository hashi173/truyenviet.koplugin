local ffi = require("ffi")
local bit = require("bit")

ffi.cdef[[
typedef struct evp_md_st EVP_MD;
typedef struct evp_cipher_st EVP_CIPHER;

const EVP_MD *EVP_sha512(void);
int PKCS5_PBKDF2_HMAC(const char *pass, int passlen,
                      const unsigned char *salt, int saltlen, int iter,
                      const EVP_MD *digest,
                      int keylen, unsigned char *out);
unsigned char *HMAC(const EVP_MD *evp_md, const void *key, int key_len,
                    const unsigned char *d, size_t n, unsigned char *md,
                    unsigned int *md_len);
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
local saltHex = "c1c6ad39eae7cf239bff283a5fa324fe2e867aa2d5887c471376acb10d78245054a37fb6720255050d8781d1ed5894182184de1a335233ce63029297432a1c13188e6ee60e55663f01fb56dec5ee117c84ce939e99a1741bbe240db8f198ce0f2f7ccd84cf9cb04522284c508de7d88a3efac7060a8a02e8235269ec5a85ee7776701af97712f1b363aef5b27343cd2c4018588f9316cb56e6dca3ffa5ecc6f78ab99c0b4208dbd4ac798d9a4371b82dc334b197f9d9c2c61033c905273c1fb82611518c3ff8cf2517fa129562ba8bb83adb593e5f241691e19a5d1c307973ec2f54990506058c41d6f98b529a7f6d7919727504d90952c2c03244291bce18a4"
local salt = hex2bin(saltHex)

-- Standard implementation
local derivedKey_std = ffi.new("unsigned char[32]")
local res = libcrypto.PKCS5_PBKDF2_HMAC(keyStr, #keyStr, salt, #salt, 999, libcrypto.EVP_sha512(), 32, derivedKey_std)
assert(res == 1, "Standard PBKDF2 failed")
local std_hex = ""
for i=0,31 do
    std_hex = std_hex .. string.format("%02x", derivedKey_std[i])
end
print("Standard derived key hex: " .. std_hex)

-- Custom fallback implementation
local function pbkdf2_hmac_sha512(libcrypto, password, salt, iterations, key_len)
    local hLen = 64
    local l = math.ceil(key_len / hLen)
    
    local u_in = ffi.new("unsigned char[64]")
    local u_out = ffi.new("unsigned char[64]")
    local t = ffi.new("unsigned char[64]")
    local md_len = ffi.new("unsigned int[1]")
    
    local derived_key = ffi.new("unsigned char[?]", l * hLen)
    
    for i = 1, l do
        -- INT_32_BE(i)
        local i_bin = string.char(
            bit.rshift(i, 24) % 256,
            bit.rshift(i, 16) % 256,
            bit.rshift(i, 8) % 256,
            i % 256
        )
        
        -- U_1 = HMAC(Password, Salt || INT_32_BE(i))
        local u_input = salt .. i_bin
        libcrypto.HMAC(libcrypto.EVP_sha512(), password, #password, u_input, #u_input, u_in, md_len)
        ffi.copy(t, u_in, 64)
        
        for j = 2, iterations do
            -- U_j = HMAC(Password, U_{j-1})
            libcrypto.HMAC(libcrypto.EVP_sha512(), password, #password, u_in, 64, u_out, md_len)
            -- XOR t and u_out, and copy u_out to u_in for the next iteration
            for k = 0, 63 do
                t[k] = bit.bxor(t[k], u_out[k])
                u_in[k] = u_out[k]
            end
        end
        
        ffi.copy(derived_key + (i - 1) * hLen, t, hLen)
    end
    
    return derived_key
end

local derivedKey_fallback = pbkdf2_hmac_sha512(libcrypto, keyStr, salt, 999, 32)
local fallback_hex = ""
for i=0,31 do
    fallback_hex = fallback_hex .. string.format("%02x", derivedKey_fallback[i])
end
print("Fallback derived key hex: " .. fallback_hex)

if std_hex == fallback_hex then
    print("SUCCESS: Both keys are exactly equal!")
else
    print("FAILURE: Keys differ!")
end

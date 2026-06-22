const fs = require('fs');

// Load crypto-js
const CryptoJS = require('./crypto-js.min.js');

const InitMangaData = {
    "decryption_key": "OENBNkU0NUYxQzREMEFDQg=="
};

const InitMangaEncryptedChapter = {
    "ciphertext": "6OM8MV4/QcwETs10expZgWRxSPeRYsXBVWnpOT83M8Amnz2yuaJN7WASrBTvKJDoXDWhrR54Ct+Rh/kBUBfeJ71IFB99quGgjH6a2SPb880Ie3AGFXhCAdEkETQtvva3dTR5WmP8/9ir65mB7mFmPX5Uj1p1wK28CUSY6BTzSnH3VQcgCjJn2e+IepdLT28BPjBCVO7Y/vWz7/YckB3W7Bl8V3tfUNxg39j9ym+yuMdR0DIzwl07qMQm+0srifkMu8HyFwRGY/Gfw7Ch7BwuACiPzoQCP4mWQs1NCXYf9LplhGShMRIpqRJq5q6LPMcPQTzbfWK3ZrNWvXjME2J17LjXDP7BPCK8RIkzvLDlFx9FMozaKDn+aydteeNbPb6FcAfc1hVTcZLG2iC78bjN+Z2pxa9ZyiBByRlgDXj7/l7qa1xMN2CTLu3MQrhfEQQAjyonQQtItfU/ueqSFtlqfuUYuacRQ5l2o0APYcEckSIbiLRvBB5KumaZvW4tst6ktjgqYc9QWlh0vkds9jujUZKFOqaNMZvrydmn3VmTZKsjBXtJKaVrH/Cn4W+QRJCU8sLKK7i+FNrx2F8X0bQXfVuiP8jVz6S1TY5b6JI/liEtzYGdpNi1/rwTJagz2e67gA2KLRQScq/XNaarIaHKaN3SRvdWSXSijF1NAWPjVSCry0vjBSf1hw1BJ0UG1zEv6yoKnn2NtYgkil5IRwUF2Ui2Skl56ZkUJluWdXtxQYerkwAk3NT6Zt1EYn+jM8VxT1N8PWRXP5TOU9OHHIV8nl2F1EcGaIlYzv8Ka3l1ILUgZNLNfHYViRp16PNtweDadpH53uzO42Gw7FP2Bjvi5f7tPZy0y0gPooW7ot9PGMW1XDrcotwh4ZlXa+IQVEKqKWrC+wY6X65s1q5/JTlNY4oR707MKRw9JZkGWYsgSwDEIBJxoCArf2s56BoX1GbgDQ8qEHfnWAONDfUmdaSLw70wEcl6hqaXU6ei8ibJByPL2vrQtNsD6zYToPGakOJiSs5xaV95m4raWAHKrICspq4yOZbr38XLUguabhz6vOV+/WqEKamP+H8opCKplcQ3MqK1ygkGnPDYHoyX4YjsE/nLVhvwrx0yAJVrmh6HNgJkoA0ayK6MGP2EEVyyQe3jedPJ3gJeyVlZrVjeVi3jQO+kIM9/1ROptIwM4ofnEj5iynYDeoD1//mjJJ47yPORGD/eS12EBW6rhxgRlIdrZJTm1qrMomNLq/4X4VEJyTf7PDmFgLn2+s47sgreoXTYzU5ltH8HD9Wg70m1flBIi1PP6XbHHSkrFWcJWjUwI7TyxoqeWRpBA9rp7GNelBMZBMdjUEBr9Wayajhq/26EWU0UUNkUPjGq+caZvhEpZHKgWHeFEpbKLGOfwIsWXdUF/ZQ/+nrer6esVl/DcOXC+wNmgMSL3oW1ym4b0ePpMtDCb41YgwnQ3hNg6WNJS4okExAddciHcvxaJvZP5cLtfQ==",
    "iv": "0ec780ebd4cf7b5f6e401dd19903d681",
    "salt": "c1c6ad39eae7cf239bff283a5fa324fe2e867aa2d5887c471376acb10d78245054a37fb6720255050d8781d1ed5894182184de1a335233ce63029297432a1c13188e6ee60e55663f01fb56dec5ee117c84ce939e99a1741bbe240db8f198ce0f2f7ccd84cf9cb04522284c508de7d88a3efac7060a8a02e8235269ec5a85ee7776701af97712f1b363aef5b27343cd2c4018588f9316cb56e6dca3ffa5ecc6f78ab99c0b4208dbd4ac798d9a4371b82dc334b197f9d9c2c61033c905273c1fb82611518c3ff8cf2517fa129562ba8bb83adb593e5f241691e19a5d1c307973ec2f54990506058c41d6f98b529a7f6d7919727504d90952c2c03244291bce18a4"
};

const keyStrBase64 = InitMangaData.decryption_key;
const keyStr = Buffer.from(keyStrBase64, 'base64').toString('utf8');

console.log("Decoded Key:", keyStr);

// Mode 1: Using key as password
try {
    const decrypted1 = CryptoJS.AES.decrypt(
        InitMangaEncryptedChapter.ciphertext,
        keyStr
    ).toString(CryptoJS.enc.Utf8);
    if (decrypted1) {
        console.log("Mode 1 success! Length:", decrypted1.length);
        console.log(decrypted1.substring(0, 100));
        process.exit(0);
    }
} catch (e) {
    console.log("Mode 1 failed");
}

// Mode 2: Custom params (IV + Key parse)
try {
    const decrypted2 = CryptoJS.AES.decrypt(
        InitMangaEncryptedChapter.ciphertext,
        CryptoJS.enc.Utf8.parse(keyStr),
        {
            iv: CryptoJS.enc.Hex.parse(InitMangaEncryptedChapter.iv),
            mode: CryptoJS.mode.CBC,
            padding: CryptoJS.pad.Pkcs7
        }
    ).toString(CryptoJS.enc.Utf8);
    if (decrypted2) {
        console.log("Mode 2 success! Length:", decrypted2.length);
        console.log(decrypted2.substring(0, 100));
        process.exit(0);
    }
} catch (e) {
    console.log("Mode 2 failed");
}

// Mode 3: Using ciphertext + salt formatting for password
try {
    // CryptoJS format uses Salted__ + salt + ciphertext, but maybe it's just decrypting as cipher params
    var cipherParams = CryptoJS.lib.CipherParams.create({
        ciphertext: CryptoJS.enc.Base64.parse(InitMangaEncryptedChapter.ciphertext),
        salt: CryptoJS.enc.Hex.parse(InitMangaEncryptedChapter.salt)
    });
    const decrypted3 = CryptoJS.AES.decrypt(
        cipherParams,
        keyStr
    ).toString(CryptoJS.enc.Utf8);
    if (decrypted3) {
        console.log("Mode 3 success! Length:", decrypted3.length);
        console.log(decrypted3.substring(0, 100));
        process.exit(0);
    }
} catch (e) {
    console.log("Mode 3 failed");
}

console.log("All modes failed!");

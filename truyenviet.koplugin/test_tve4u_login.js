const https = require('https');

function parseCookies(setCookie) {
    if (!setCookie) return [];
    if (typeof setCookie === 'string') setCookie = [setCookie];
    return setCookie.map(c => c.split(';')[0]);
}

function getLoginToken() {
    return new Promise((resolve, reject) => {
        https.get('https://tve-4u.org/login/', (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                const match = data.match(/name="?_xfToken"?\s*value="?([^"']+)"?/i) ||
                              data.match(/_xfToken["']?\s*:\s*["']([^"']+)["']/i);
                resolve({
                    token: match ? match[1] : '',
                    cookies: parseCookies(res.headers['set-cookie'])
                });
            });
        }).on('error', reject);
    });
}

function login(token, cookies) {
    return new Promise((resolve, reject) => {
        const body = `login=${encodeURIComponent('phamthithienha17032005@gmail.com')}&password=${encodeURIComponent('Thienh@17032005')}&remember=1&_xfRedirect=${encodeURIComponent('https://tve-4u.org/')}&_xfToken=${encodeURIComponent(token)}`;
        const req = https.request('https://tve-4u.org/login/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Content-Length': Buffer.byteLength(body),
                'Cookie': cookies.join('; '),
                'User-Agent': 'Mozilla/5.0'
            }
        }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                resolve({
                    status: res.statusCode,
                    headers: res.headers,
                    body: data
                });
            });
        });
        req.on('error', reject);
        req.write(body);
        req.end();
    });
}

(async () => {
    try {
        const { token, cookies } = await getLoginToken();
        console.log('Token:', token);
        console.log('Initial Cookies:', cookies);
        const { status, headers, body } = await login(token, cookies);
        console.log('Login Status:', status);
        console.log('Login Set-Cookie:', headers['set-cookie']);
        console.log('Body length:', body.length);
        if (body.includes('lỗi')) console.log('Found "lỗi" in body');
        if (body.includes('Sai')) console.log('Found "Sai" in body');
    } catch(e) {
        console.error(e);
    }
})();

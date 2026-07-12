const https = require('https');
https.get('https://tve-4u.org/login/', (res) => {
    let data = '';
    res.on('data', c => data += c);
    res.on('end', () => {
        const formMatch = data.match(/<form[^>]*action="[^"]*login\/login[^"]*"[^>]*>([\s\S]*?)<\/form>/i);
        if (formMatch) {
            const inputs = formMatch[1].match(/<input[^>]*>/gi);
            console.log(inputs ? inputs.map(i => i.match(/name="([^"]+)"/)?.[1]).filter(Boolean) : 'No inputs found');
        } else {
            console.log('Login form not found');
        }
    });
});

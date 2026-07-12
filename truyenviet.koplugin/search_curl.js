const { execSync } = require('child_process');
try {
    const res = execSync('wsl -d Ubuntu -e grep -ri "ffi.load.*curl" /usr/lib/koreader/');
    console.log(res.toString());
} catch (e) {
    console.log(e.stdout.toString());
}

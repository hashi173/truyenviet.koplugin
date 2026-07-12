const fs = require('fs');
const html = fs.readFileSync('mizzya_home.html', 'utf8');
const classes = html.match(/class="[^"]+"/g);
if (classes) {
    const unique = Array.from(new Set(classes));
    console.log(unique.slice(0, 50).join('\n'));
}

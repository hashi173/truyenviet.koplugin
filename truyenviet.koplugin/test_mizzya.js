const fs = require('fs');
const html = fs.readFileSync('mizzya_test4.html', 'utf8');

const regexes = [
    /<div class="entry-content">([\s\S]*?)<footer/,
    /<div class="entry-content">([\s\S]*?)<div id="jp-post-flair"/,
    /<div class="entry-content">([\s\S]*?)<\/article>/
];

for (const r of regexes) {
    const match = html.match(r);
    if (match) {
        console.log("Matched!", r);
        return;
    }
}
console.log("NO MATCH");

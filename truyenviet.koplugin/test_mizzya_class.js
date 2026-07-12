const fs = require('fs');
const html = fs.readFileSync('mizzya_test5.html', 'utf8');
const match = html.match(/class="[^"]*entry-content[^"]*"/);
if (match) {
    console.log("MATCH:", match[0]);
    const idx = html.indexOf(match[0]);
    console.log(html.substring(idx - 20, idx + 200));
} else {
    console.log("NO ENTRY CONTENT");
    // Find where the content starts, maybe <div class="post-content"> ?
    const c1 = html.match(/class="[^"]*content[^"]*"/g);
    console.log(c1 ? c1.slice(0, 5) : 'no content classes');
}

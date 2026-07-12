const fs = require('fs');
const html = fs.readFileSync('mizzya_home.html', 'utf8');
const match = html.match(/<div class="entry-content">([\s\S]*?)<\/div>\s*<footer/);
if (match) {
    const content = match[1];
    const links = content.match(/<a[^>]+href="([^"]+)"[^>]*>([^<]+)<\/a>/g);
    console.log("Found links:", links ? links.length : 0);
    if (links) {
        console.log(links.slice(0, 5));
    }
} else {
    console.log("content not found");
}

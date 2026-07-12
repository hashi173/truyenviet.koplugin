const fs = require('fs');
const html = fs.readFileSync('mizzya_home.html', 'utf8');
const match = html.match(/<div class="entry-content">([\s\S]*?)<footer/);
if (match) {
    const links = match[1].match(/<a[^>]+href="([^"]+)"[^>]*>([^<]+)<\/a>/g);
    console.log("Found links:", links ? links.length : 0);
    if (links) console.log(links.slice(0, 3));
} else {
    console.log("not found");
}

const fs = require('fs');
const data = fs.readFileSync('tve4u_logged_in.html', 'utf8');
const links = data.match(/href="([^"]+)"/g);
if (links) {
    const uniqueLinks = Array.from(new Set(links.map(l => l.replace(/href="|"/g, ''))));
    for (const link of uniqueLinks) {
        if (link.includes('diendan') || link.includes('forum') || link.includes('box')) {
            console.log(link);
        }
    }
}

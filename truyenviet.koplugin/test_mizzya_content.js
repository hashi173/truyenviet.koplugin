const fs = require('fs');
const html = fs.readFileSync('mizzya_home.html', 'utf8');
const start = html.indexOf('class="entry-content"');
if (start !== -1) {
    const contentHtml = html.substring(start, html.indexOf('</footer>', start) + 100);
    console.log("End of content block:", contentHtml.substring(contentHtml.length - 200));
} else {
    console.log("entry-content not found");
}

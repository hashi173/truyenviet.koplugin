const fs = require('fs');
const html = fs.readFileSync('tve4u_thread.html', 'utf8');

// Parse posts
const posts = [];
// XenForo 2 post structure
const postRegex = /<article[^>]*class="[^"]*message[^"]*"[^>]*>([\s\S]*?)<\/article>/g;

let match;
while ((match = postRegex.exec(html)) !== null) {
    const postHtml = match[1];
    
    // Author
    let authorMatch = postHtml.match(/<a[^>]*class="[^"]*username[^"]*"[^>]*>([\s\S]*?)<\/a>/);
    let author = authorMatch ? authorMatch[1].replace(/<[^>]+>/g, '').trim() : "Unknown";
    
    // Date
    let dateMatch = postHtml.match(/<time[^>]*data-date-string="([^"]+)"/);
    let date = dateMatch ? dateMatch[1] : "";
    
    // Content
    let contentMatch = postHtml.match(/<div class="bbWrapper">([\s\S]*?)<\/div>\s*<\/div>/);
    if (!contentMatch) {
        contentMatch = postHtml.match(/<div class="message-content">[\s\S]*?<article>[\s\S]*?<div class="message-body">([\s\S]*?)<\/div>\s*<\/article>/);
    }
    let content = contentMatch ? contentMatch[1] : "";
    
    posts.push({ author, date, contentLen: content.length });
}

console.log(posts);

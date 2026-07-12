const fs = require('fs');
const html = fs.readFileSync('tve4u_thread.html', 'utf8');

const posts = [];
const postRegex = /<li[^>]*class="[^"]*message\b[^"]*"[^>]*>([\s\S]*?)<\/li>\s*(?:<li[^>]*class="[^"]*message\b|$)/g;
// Actually XenForo 1 uses <li id="post-xxx" class="message   " data-author="xxx">
const postRegex2 = /<li[^>]*class="[^"]*message\b[^"]*"[^>]*>([\s\S]*?)<div class="messageMeta/g;

let match;
while ((match = postRegex2.exec(html)) !== null) {
    const postHtml = match[1];
    
    // Author
    let authorMatch = postHtml.match(/data-author="([^"]+)"/);
    if (!authorMatch) authorMatch = postHtml.match(/class="username"[^>]*>([\s\S]*?)<\/a>/);
    let author = authorMatch ? authorMatch[1].replace(/<[^>]+>/g, '').trim() : "Unknown";
    
    // Date
    let dateMatch = postHtml.match(/<span class="DateTime"[^>]*>([^<]+)<\/span>/);
    if (!dateMatch) dateMatch = postHtml.match(/data-datestring="([^"]+)"/);
    let date = dateMatch ? dateMatch[1] : "";
    
    // Content
    let contentMatch = postHtml.match(/<blockquote class="messageText[^"]*">([\s\S]*?)<\/blockquote>/);
    let content = contentMatch ? contentMatch[1] : "";
    
    posts.push({ author, date, contentLen: content.length });
}

console.log(posts);

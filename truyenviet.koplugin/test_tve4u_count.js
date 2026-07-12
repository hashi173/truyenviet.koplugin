const fs = require('fs');
const html = fs.readFileSync('tve4u_thread.html', 'utf8');
const match = html.match(/<li id="post-/g);
console.log(match ? match.length : 0);

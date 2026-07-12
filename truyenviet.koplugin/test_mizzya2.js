const fs = require('fs');
const html = fs.readFileSync('mizzya_test5.html', 'utf8');

const regex1 = /<div class="entry-content">([\s\S]*?)<footer/;
console.log("Match1:", !!html.match(regex1));

const regex2 = /<div class="entry-content">([\s\S]*?)<div id="jp-post-flair"/;
console.log("Match2:", !!html.match(regex2));

const regex3 = /<div class="entry-content">([\s\S]*?)<\/article>/;
console.log("Match3:", !!html.match(regex3));

const regex4 = /class="entry-content">([\s\S]*?)<footer/;
console.log("Match4:", !!html.match(regex4));

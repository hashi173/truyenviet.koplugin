const fs = require('fs');
const html = fs.readFileSync('tve4u_thread.html', 'utf8');
const classes = html.match(/class="[^"]*message[^"]*"/g);
console.log(classes ? classes.slice(0, 10) : 'none');

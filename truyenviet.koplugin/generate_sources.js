const fs = require('fs');
const path = require('path');

function getFiles(dir, files = []) {
  const fileList = fs.readdirSync(dir);
  for (const file of fileList) {
    const name = dir + '/' + file;
    if (fs.statSync(name).isDirectory()) {
      getFiles(name, files);
    } else if (name.endsWith('.lua')) {
      files.push(name);
    }
  }
  return files;
}

const root = 'd:/Project/truyenfull/truyenviet.koplugin';
const luaFiles = getFiles(root);

let markdown = '# Project Sources\n\n';

for (const file of luaFiles) {
  const relativePath = path.relative('d:/Project/truyenfull', file).replace(/\\/g, '/');
  const content = fs.readFileSync(file, 'utf8');
  markdown += `## ${relativePath}\n\n`;
  markdown += '```lua\n';
  markdown += content;
  if (!content.endsWith('\n')) markdown += '\n';
  markdown += '```\n\n';
}

fs.writeFileSync('d:/Project/truyenfull/project_sources.md', markdown);
console.log(`Written ${luaFiles.length} files to project_sources.md`);

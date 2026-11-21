#!/usr/bin/env python3
"""Read-only structural check of an EPUB produced by the plugin.

Usage: python3 spec/check_epub.py path/to/book.epub
Checks OCF rules (mimetype first + stored), container/OPF presence, that every
XML/XHTML entry is well-formed, and that every manifest href exists.
"""
import sys
import zipfile
import xml.etree.ElementTree as ET

path = sys.argv[1]
errors = []
with zipfile.ZipFile(path) as z:
    infos = z.infolist()
    first = infos[0]
    if first.filename != "mimetype":
        errors.append("first entry is %r, expected 'mimetype'" % first.filename)
    if first.compress_type != zipfile.ZIP_STORED:
        errors.append("mimetype is compressed")
    if z.read("mimetype") != b"application/epub+zip":
        errors.append("bad mimetype content")
    if z.testzip() is not None:
        errors.append("CRC error in archive")
    names = set(z.namelist())
    for name in ("META-INF/container.xml", "OEBPS/content.opf", "OEBPS/nav.xhtml"):
        if name not in names:
            errors.append("missing " + name)
    for name in sorted(names):
        if name.endswith((".xml", ".opf", ".xhtml")):
            try:
                ET.fromstring(z.read(name))
            except ET.ParseError as exc:
                errors.append("%s not well-formed: %s" % (name, exc))
    opf = ET.fromstring(z.read("OEBPS/content.opf"))
    ns = {"opf": "http://www.idpf.org/2007/opf"}
    for item in opf.findall(".//opf:manifest/opf:item", ns):
        href = "OEBPS/" + item.get("href")
        if href not in names:
            errors.append("manifest href missing: " + href)
    if opf.find(".//opf:meta[@property='dcterms:modified']", ns) is None:
        errors.append("missing dcterms:modified")
    print("entries:", ", ".join(i.filename for i in infos))

if errors:
    print("EPUB CHECK FAILED")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("EPUB CHECK OK:", path)

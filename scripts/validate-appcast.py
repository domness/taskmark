"""Fail release packaging if Sparkle did not emit a signed, correctly targeted update."""

import base64
import pathlib
import sys
import xml.etree.ElementTree as ET

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def validate(feed, archive, build, version):
    items = ET.parse(feed).findall("./channel/item")
    if len(items) != 1:
        raise ValueError("Expected exactly one update in the release feed")
    item = items[0]
    enclosure = item.find("enclosure")
    if enclosure is None:
        raise ValueError("Missing update enclosure")
    signature = base64.b64decode(enclosure.get(SPARKLE + "edSignature", ""), validate=True)
    if len(signature) != 64:
        raise ValueError("Missing or malformed EdDSA archive signature")
    tag = archive.name.removeprefix("Taskmark-").removesuffix("-universal.zip")
    expected = f"https://github.com/domness/taskmark/releases/download/{tag}/{archive.name}"
    if enclosure.get("url") != expected or int(enclosure.get("length", "0")) != archive.stat().st_size:
        raise ValueError("Update URL or archive size does not match the packaged ZIP")
    if item.findtext(SPARKLE + "version") != build or item.findtext(SPARKLE + "shortVersionString") != version:
        raise ValueError("Update version does not match the packaged app")
    if item.findtext(SPARKLE + "minimumSystemVersion") != "15.0":
        raise ValueError("Unexpected minimum macOS version")


if __name__ == "__main__":
    validate(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3], sys.argv[4])

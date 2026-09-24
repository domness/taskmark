"""Validate release-feed failures without signing credentials or network access."""

import base64
import importlib.util
import pathlib
import tempfile
import unittest
import xml.etree.ElementTree as ET

SPEC = importlib.util.spec_from_file_location("appcast", pathlib.Path(__file__).with_name("validate-appcast.py"))
APPCAST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(APPCAST)


class AppcastTests(unittest.TestCase):
    def test_feed_contract_and_invalid_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            archive = root / "Taskmark-v1.2.3-universal.zip"
            archive.write_bytes(b"fixture archive")
            feed = root / "appcast.xml"
            rss = ET.Element("rss")
            item = ET.SubElement(ET.SubElement(rss, "channel"), "item")
            ET.SubElement(item, APPCAST.SPARKLE + "version").text = "42.1"
            ET.SubElement(item, APPCAST.SPARKLE + "shortVersionString").text = "1.2.3"
            ET.SubElement(item, APPCAST.SPARKLE + "minimumSystemVersion").text = "15.0"
            enclosure = ET.SubElement(item, "enclosure", {
                "url": "https://github.com/domness/taskmark/releases/download/v1.2.3/" + archive.name,
                "length": str(archive.stat().st_size),
                APPCAST.SPARKLE + "edSignature": base64.b64encode(bytes(64)).decode(),
            })

            def validate():
                ET.ElementTree(rss).write(feed)
                APPCAST.validate(feed, archive, "42.1", "1.2.3")

            validate()
            for key, value in (("url", "https://example.com/update.zip"), ("length", "1"),
                               (APPCAST.SPARKLE + "edSignature", "")):
                original = enclosure.get(key)
                enclosure.set(key, value)
                with self.assertRaises(ValueError):
                    validate()
                enclosure.set(key, original)
            for name in ("version", "shortVersionString", "minimumSystemVersion"):
                element = item.find(APPCAST.SPARKLE + name)
                original = element.text
                element.text = "0"
                with self.assertRaises(ValueError):
                    validate()
                element.text = original
            item.remove(enclosure)
            with self.assertRaises(ValueError):
                validate()


if __name__ == "__main__":
    unittest.main()

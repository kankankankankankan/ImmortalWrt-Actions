import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('gate', Path(__file__).with_name('check-daede-feed.py'))
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

class FeedGate(unittest.TestCase):
    def test_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.config').write_text('\n'.join(f'CONFIG_PACKAGE_{p}=y' for p in gate.PACKAGES))
            links = root / 'package/feeds/immortalwrt'
            links.mkdir(parents=True)
            for package in gate.PACKAGES:
                source = root / 'feeds/immortalwrt/openwrt-daede' / package
                source.mkdir(parents=True)
                (source / 'Makefile').write_text('PKG_VERSION:=2026.09.20\nPKG_RELEASE:=3\n')
                (links / package).symlink_to(source)
            gate.check(root)
            manifest = root / 'bin/targets/x86/64/test.manifest'
            manifest.parent.mkdir(parents=True)
            content = '\n'.join(f'{p} - 2026.09.20-r3' for p in gate.PACKAGES)
            manifest.write_text(content)
            gate.check(root, True)
            manifest.write_text(content.replace('dae - 2026.09.20-r3', 'dae - 1.0.0-r1'))
            with self.assertRaisesRegex(AssertionError, 'expected'):
                gate.check(root, True)
            manifest.unlink()
            with self.assertRaisesRegex(AssertionError, 'no firmware'):
                gate.check(root, True)
            (root / '.config').write_text('CONFIG_PACKAGE_dae=m\n')
            with self.assertRaisesRegex(AssertionError, 'not built'):
                gate.check(root)
            (links / 'dae').unlink()
            (links / 'dae').symlink_to(root / 'feeds/packages/net/dae')
            with self.assertRaisesRegex(AssertionError, 'wrong/duplicate'):
                gate.check(root)

unittest.main()

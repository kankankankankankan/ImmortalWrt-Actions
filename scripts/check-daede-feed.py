#!/usr/bin/env python3
"""2026-09-23: fail closed on wrong daede feed, selection or image versions."""
import argparse
import pathlib
import re

PACKAGES = ('dae', 'daed', 'luci-app-daede')

def check(root, manifest=False):
    expected = {}
    for package in PACKAGES:
        source = root / 'feeds/immortalwrt/openwrt-daede' / package
        assert (source / 'Makefile').is_file(), f'missing custom source: {package}'
        links = list((root / 'package/feeds').glob(f'*/{package}'))
        assert len(links) == 1 and links[0].resolve() == source.resolve(), f'wrong/duplicate feed links: {package}: {links}'
        makefile = (source / 'Makefile').read_text()
        def field(name):
            found = re.findall(rf'^{name}\s*:=\s*([\w.\-]+)\s*$', makefile, re.M)
            assert len(found) == 1, f'unsupported {name}: {package}'
            return found[0]
        expected[package] = f'{field("PKG_VERSION")}-r{field("PKG_RELEASE")}'
        print(f'{package}: {links[0]} -> {source} ({expected[package]})')
    config = (root / '.config').read_text()
    for package in PACKAGES:
        assert f'CONFIG_PACKAGE_{package}=y' in config.splitlines(), f'not built into firmware: {package}'
    if manifest:
        manifests = list((root / 'bin/targets').glob('*/*/*.manifest'))
        assert manifests, 'no firmware manifests found'
        for path in manifests:
            entries = {}
            for line in path.read_text().splitlines():
                name, sep, version = line.partition(' - ')
                if sep:
                    assert name not in entries, f'duplicate package in {path}: {name}'
                    entries[name] = version
            for package, version in expected.items():
                assert entries.get(package) == version, f'{path}: {package}: expected {version}, got {entries.get(package)}'
            print(f'verified {path}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=pathlib.Path)
    parser.add_argument('--manifest', action='store_true')
    args = parser.parse_args()
    check(args.root, args.manifest)

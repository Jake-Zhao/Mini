#!/usr/bin/env python3
"""One command to import the exact approved binary masters and build all runtime art.

Usage:
  python3 tools/import_art_masters.py ~/Downloads/JAKE_DRIVE_REPO_ASSETS.zip

No network access and no credentials required. Only three known file paths are copied.
"""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
ROOT=Path(__file__).resolve().parents[1]
SOURCES={
 'Source/Vehicle/car_master.png':'ca8006f4efe1ab3a0f40a4a72a7161eb0ef1744374dc2589756f6dc32aabc9ee',
 'Source/Vehicle/rear_original.png':'0377d987c9a3c66ed1b040e5b60ed96affcc4edaf8c650303698aa1c59e723d5',
 'Reference/APPROVED.png':'da8498daf0c5effce4c5654e34cec7de95c4b85af62f8a7eb25af608c276deed'
}
def verify(name,data):
    got=hashlib.sha256(data).hexdigest()
    if got != SOURCES[name]:
        raise ValueError(f'{name}: wrong source master; refusing unapproved image ({got})')
def import_zip(path):
    with zipfile.ZipFile(path) as z:
        names=z.namelist()
        for rel in SOURCES:
            matches=[name for name in names if name == rel or name.endswith('/'+rel)]
            if len(matches)!=1:raise ValueError(f'{rel}: expected exactly one entry in archive, got {len(matches)}')
            info=z.getinfo(matches[0])
            if info.file_size > 10*1024*1024:raise ValueError(f'Unexpected master size: {rel}')
            raw=z.read(info)
            verify(rel,raw)
            dst=ROOT/rel
            dst.parent.mkdir(parents=True,exist_ok=True)
            dst.write_bytes(raw)
            print('IMPORTED',rel,len(raw),'bytes')
def import_dir(path):
    for rel in SOURCES:
        candidates=[path/rel,path/Path(rel).name]
        src=next((p for p in candidates if p.is_file()),None)
        if not src:raise FileNotFoundError(f'Missing {rel} in {path}')
        raw=src.read_bytes();verify(rel,raw)
        dst=ROOT/rel;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(raw)
        print('IMPORTED',rel,len(raw),'bytes')
def run(script):
    print('RUN',script,flush=True)
    subprocess.run([sys.executable,str(ROOT/'tools'/script)],check=True,cwd=ROOT)
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('archive_or_folder',type=Path)
    p.add_argument('--sources-only',action='store_true',help='Only install the three image masters')
    args=p.parse_args()
    if args.archive_or_folder.is_dir():import_dir(args.archive_or_folder)
    elif zipfile.is_zipfile(args.archive_or_folder):import_zip(args.archive_or_folder)
    else:raise ValueError('Provide a ZIP containing the master files or a source directory')
    subprocess.run([sys.executable,str(ROOT/'tools/check_assets.py'),'--sources-only'],check=True)
    if not args.sources_only:
        run('build_assets.py');run('build_app_icons.py');run('make_project.py');run('check_assets.py')
    print('ART IMPORT COMPLETE')
if __name__=='__main__':main()

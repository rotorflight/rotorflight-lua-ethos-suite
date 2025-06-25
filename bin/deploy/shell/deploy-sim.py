#!/usr/bin/env python3
import os
import sys
import shutil
import re
import argparse
import stat
import csv

def on_rm_error(func, path, exc_info):
    # Make read-only files writable and retry
    os.chmod(path, stat.S_IWRITE)
    func(path)

def get_destfolders():
    env = os.environ.get('FRSKY_SIM_SRC')
    if not env:
        print('Error: environment variable FRSKY_SIM_SRC is not set', file=sys.stderr)
        sys.exit(1)
    # Parse CSV list of paths
    return next(csv.reader([env], skipinitialspace=True))

def main():
    parser = argparse.ArgumentParser(description='Deploy simulation scripts to multiple Ethos Suite paths')
    parser.add_argument('ext', nargs='?', default=None,
                        help='Optional file extension filter, e.g. .lua')
    args = parser.parse_args()

    srcfolder = os.environ.get('FRSKY_RFSUITE_GIT_SRC')
    if not srcfolder:
        print('Error: environment variable FRSKY_RFSUITE_GIT_SRC is not set', file=sys.stderr)
        sys.exit(1)

    destfolders = get_destfolders()
    tgt_dir = 'rfsuite'

    for raw_dest in destfolders:
        dest = raw_dest.strip().strip('"')
        target = os.path.join(dest, tgt_dir)
        print(f'Processing destination folder: {dest}')

        if args.ext == '.lua':
            print(f'Removing all .lua files from {target}...')
            if os.path.isdir(target):
                for root, dirs, files in os.walk(target):
                    for file in files:
                        if file.lower().endswith('.lua'):
                            os.remove(os.path.join(root, file))

            print(f'Syncing only .lua files to {target}...')
            src = os.path.join(srcfolder, 'scripts', tgt_dir)
            for root, dirs, files in os.walk(src):
                rel = os.path.relpath(root, src)
                dest_dir = os.path.join(target, rel)
                os.makedirs(dest_dir, exist_ok=True)
                for file in files:
                    if file.lower().endswith('.lua'):
                        shutil.copy2(os.path.join(root, file), dest_dir)

        else:
            print(f'Removing entire target folder: {target}...')
            if os.path.exists(target):
                shutil.rmtree(target, onerror=on_rm_error)

            print(f'Copying all files to {target}...')
            src = os.path.join(srcfolder, 'scripts', tgt_dir)
            shutil.copytree(src, target)

        print(f'Copy completed for: {dest}')

    print('Script execution completed.')

if __name__ == '__main__':
    main()

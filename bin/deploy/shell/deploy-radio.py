#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil
import re
import argparse
import stat
from tqdm import tqdm

def on_rm_error(func, path, exc_info):
    os.chmod(path, stat.S_IWRITE)
    func(path)

def get_dstfolder(ethos_bin):
    result = subprocess.run([ethos_bin, '--get-path', 'SCRIPTS'],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in result.stdout.splitlines():
        if re.match(r'^[A-Za-z]:[\\/]', line):
            return line.strip()
    print('Error: could not determine SCRIPTS folder.', file=sys.stderr)
    sys.exit(1)

def collect_all_files(src, filter_ext=None):
    all_files = []
    for root, dirs, files in os.walk(src):
        rel = os.path.relpath(root, src)
        for file in files:
            if not filter_ext or file.lower().endswith(filter_ext):
                all_files.append((os.path.join(root, file), os.path.join(rel, file)))
    return all_files

def main():
    parser = argparse.ArgumentParser(description='Deploy scripts via Ethos Suite')
    parser.add_argument('ext', nargs='?', default=None, help='File extension filter, e.g. .lua')
    args = parser.parse_args()

    tgt_dir = 'rfsuite'
    srcfolder = os.environ.get('FRSKY_RFSUITE_GIT_SRC')
    ethos_bin = os.environ.get('FRSKY_ETHOS_SUITE_BIN')

    if not srcfolder or not ethos_bin:
        print('Environment variables FRSKY_RFSUITE_GIT_SRC and FRSKY_ETHOS_SUITE_BIN must be set', file=sys.stderr)
        sys.exit(1)

    dstfolder = get_dstfolder(ethos_bin)
    print(f'SCRIPTS folder is: {dstfolder}')
    src = os.path.join(srcfolder, 'scripts', tgt_dir)

    file_filter = ('.lua', '.luac') if args.ext == '.lua' else None
    all_files = collect_all_files(src, file_filter)

    target_path = os.path.join(dstfolder, tgt_dir)

    if args.ext == '.lua':
        print('Removing all .lua files from target...')
        for root, dirs, files in os.walk(target_path):
            for file in files:
                if file.lower().endswith(('.lua', '.luac')):
                    os.remove(os.path.join(root, file))
    else:
        print('Removing entire target folder...')
        if os.path.exists(target_path):
            shutil.rmtree(target_path, onerror=on_rm_error)
        print('Recreating target folder...')
        os.makedirs(target_path, exist_ok=True)

    print('Copying files to the destination folder...')
    with tqdm(total=len(all_files), desc='Copying files') as pbar:
        for src_path, rel_path in all_files:
            dest_path = os.path.join(target_path, rel_path)
            os.makedirs(os.path.dirname(dest_path), exist_ok=True)
            shutil.copy2(src_path, dest_path)
            pbar.update(1)

    print('Script execution completed.')

if __name__ == '__main__':
    main()

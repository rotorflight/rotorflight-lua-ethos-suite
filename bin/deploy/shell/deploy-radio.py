#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil
import re
import argparse
import stat

def on_rm_error(func, path, exc_info):
    # Change file to writable and retry
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

def remove_lua_files(target_path, tgt_dir):
    full_target = os.path.join(target_path, tgt_dir)
    for root, dirs, files in os.walk(full_target):
        for file in files:
            if file.lower().endswith('.lua'):
                os.remove(os.path.join(root, file))

def copy_lua_files(src_base, tgt_dir, target_path):
    src = os.path.join(src_base, 'scripts', tgt_dir)
    dest_base = os.path.join(target_path, tgt_dir)
    for root, dirs, files in os.walk(src):
        rel = os.path.relpath(root, src)
        dest_dir = os.path.join(dest_base, rel)
        os.makedirs(dest_dir, exist_ok=True)
        for file in files:
            if file.lower().endswith('.lua'):
                shutil.copy2(os.path.join(root, file), dest_dir)

def copy_all_files(src_base, tgt_dir, target_path):
    src = os.path.join(src_base, 'scripts', tgt_dir)
    dest = os.path.join(target_path, tgt_dir)
    if os.path.exists(dest):
        shutil.rmtree(dest, onerror=on_rm_error)
    shutil.copytree(src, dest)

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

    if args.ext == '.lua':
        print('Removing all .lua files from target...')
        remove_lua_files(dstfolder, tgt_dir)
        print('Syncing only .lua files to target...')
        copy_lua_files(srcfolder, tgt_dir, dstfolder)
    else:
        print('Removing entire target folder...')
        full_target = os.path.join(dstfolder, tgt_dir)
        if os.path.exists(full_target):
            shutil.rmtree(full_target, onerror=on_rm_error)
        print('Recreating target folder...')
        os.makedirs(full_target, exist_ok=True)
        print('Copying all files to the destination folder...')
        copy_all_files(srcfolder, tgt_dir, dstfolder)

    print('Script execution completed.')

if __name__ == '__main__':
    main()

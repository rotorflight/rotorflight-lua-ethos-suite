import os
import shutil
import argparse
from tqdm import tqdm
import subprocess_conout
import serial
import subprocess
import re
import sys

pbar = None

def copy_verbose(src, dst):
    pbar.update(1)
    shutil.copy(src, dst)


def count_files_in_tree(directory, extension=None):
    file_count = 0
    for root, dirs, files in os.walk(directory):
        if extension:
            files = [f for f in files if f.endswith(extension)]
        file_count += len(files)
    return file_count


def copy_files(src, fileext=None, launch=False, destfolders=None):
    global pbar
    if fileext:
        print(f"File extension specified: {fileext}")
    else:
        print("No file extension specified. Copying all files.")

    tgt = "rfsuite"
    srcfolder = src if src else os.getenv('DEV_RFSUITE_GIT_SRC')

    if not destfolders:
        print("Destfolders not set")
        return

    destfolders = destfolders.split(',')

    for idx, dest in enumerate(destfolders):
        print(f"[{idx+1}/{len(destfolders)}] Processing destination folder: {dest}")

        logs_temp = os.path.join(dest, 'logs_temp')
        tgt_folder = os.path.join(dest, tgt)
        logs_folder = os.path.join(tgt_folder, 'logs')

        # Preserve the logs folder by moving it temporarily
        if os.path.exists(logs_folder) and fileext != "fast":
            print(f"Backing up logs ...")
            os.makedirs(logs_temp, exist_ok=True)
            shutil.copytree(logs_folder, logs_temp, dirs_exist_ok=True)

        if fileext == ".lua":
            print(f"Removing all .lua files from target in {dest}...")
            for root, _, files in os.walk(tgt_folder):
                for file in files:
                    if file.endswith('.lua'):
                        os.remove(os.path.join(root, file))

            print(f"Syncing only .lua files to target in {dest}...")
            os.makedirs(tgt_folder, exist_ok=True)
            lua_src = os.path.join(srcfolder, 'scripts', tgt)
            for root, _, files in os.walk(lua_src):
                for file in files:
                    if file.endswith('.lua'):
                        shutil.copy(
                            os.path.join(root, file),
                            os.path.join(tgt_folder, file)
                        )

        elif fileext == "fast":
            lua_src = os.path.join(srcfolder, 'scripts', tgt)
            for root, _, files in os.walk(lua_src):
                for file in files:
                    src_file = os.path.join(root, file)
                    rel_path = os.path.relpath(src_file, lua_src)
                    tgt_file = os.path.join(tgt_folder, rel_path)

                    # Ensure the target directory exists
                    os.makedirs(os.path.dirname(tgt_file), exist_ok=True)

                    # If target file exists, compare and copy only if source is newer
                    if os.path.exists(tgt_file):
                        if os.stat(src_file).st_mtime > os.stat(tgt_file).st_mtime:
                            shutil.copy(src_file, tgt_file)
                            print(f"Copying {file} to {tgt_file}")
                    else:
                        shutil.copy(src_file, tgt_file)
                        print(f"Copying {file} to {tgt_file}")

        else:
            # No specific file extension, remove and copy all files
            if os.path.exists(tgt_folder):
                try:
                    print(f"Deleting existing folder: {tgt_folder}")
                    shutil.rmtree(tgt_folder)
                    os.makedirs(tgt_folder, exist_ok=True)

                    if os.path.exists(logs_temp):
                        os.makedirs(logs_folder, exist_ok=True)
                        print(f"Restoring logs from backup ...")
                        shutil.copytree(logs_temp, logs_folder, dirs_exist_ok=True)
                        shutil.rmtree(logs_temp)
                except OSError:
                    print("Failed to delete entire folder, replacing single files instead")

            # Copy all files to the destination folder
            print(f"Copying all files to target in {dest}...")
            all_src = os.path.join(srcfolder, 'scripts', tgt)
            num_files = count_files_in_tree(all_src)
            pbar = tqdm(total=num_files)
            shutil.copytree(
                all_src,
                tgt_folder,
                dirs_exist_ok=True,
                copy_function=copy_verbose
            )
            pbar.close()

        # Restore logs if not handled already
        if os.path.exists(logs_temp):
            print(f"Restoring logs from backup ...")
            os.makedirs(logs_folder, exist_ok=True)
            shutil.copytree(logs_temp, logs_folder, dirs_exist_ok=True)
            shutil.rmtree(logs_temp)

        print(f"Copy completed for: {dest}")

    if launch:
        cmd = launch
        ret = subprocess_conout.subprocess_conout(cmd, nrows=9999, encode=True)
        print(ret)

    print("Script execution completed.")


def main():
    parser = argparse.ArgumentParser(description='Deploy simulation files.')
    parser.add_argument('--src', type=str, help='Source folder')
    parser.add_argument('--sim', type=str, help='Launch path for the sim after deployment')
    parser.add_argument('--fileext', type=str, help='File extension to filter by')
    parser.add_argument(
    '--destfolders',
    type=str,
    nargs='?',
    const=None,
    default=None,
    help='Folders for deployment'
    )
    parser.add_argument('--radio', action='store_true', default=False,
                        help='Deploy to connected FrSky radio')
    parser.add_argument('--ethos-bin', type=str, default=None,
                        help='Path to Ethos Suite CLI (overrides FRSKY_ETHOS_SUITE_BIN)')
    parser.add_argument('--radioDebug', action='store_true', default=False,
                        help='After deploying, switch radio into debug mode')
    parser.add_argument('--radioDebugOnly', action='store_true', default=False,
                        help='Skip deploy; only switch radio into debug mode')

    args = parser.parse_args()

    # Inline helper from deploy-radio.py
    def get_scripts_folder(ethos_bin):
        result = subprocess.run(
            [ethos_bin, '--get-path', 'SCRIPTS'],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        for line in result.stdout.splitlines():
            if re.match(r'^[A-Za-z]:[\\/]', line):
                return line.strip()
        print("Error: could not determine SCRIPTS folder.", file=sys.stderr)
        sys.exit(1)

    # 1) radioDebugOnly: only debug, no deploy
    if args.radioDebugOnly:
        ethos_bin = args.ethos_bin or os.environ.get('FRSKY_ETHOS_SUITE_BIN')
        if not ethos_bin:
            print("Error: must set --ethos-bin or FRSKY_ETHOS_SUITE_BIN", file=sys.stderr)
            sys.exit(1)

        print("Debug-only: entering serial debug …")
        try:
            port = subprocess.check_output(
                [ethos_bin, '--serial', 'start'], text=True
            ).strip()
            print(f"Radio in debug mode on {port}")
            ser = serial.Serial(port=port)
            while True:
                try:
                    print(ser.readline().decode())
                except serial.serialutil.SerialException:
                    break
        except subprocess.CalledProcessError as e:
            print(f"Radio not connected: {e}")
        sys.exit(0)

    # 2) Normal or radio-driven deploy
    if args.radio:
        ethos_bin = args.ethos_bin or os.environ.get('FRSKY_ETHOS_SUITE_BIN')
        if not ethos_bin:
            print("Error: must set --ethos-bin or FRSKY_ETHOS_SUITE_BIN", file=sys.stderr)
            sys.exit(1)
        args.destfolders = get_scripts_folder(ethos_bin)

    # 3) Perform file copy/deploy
    copy_files(
        src=args.src,
        fileext=args.fileext,
        launch=args.sim,
        destfolders=args.destfolders
    )

    # 4) Post-deploy debug, if requested
    if args.radio and args.radioDebug:
        ethos_bin = args.ethos_bin or os.environ.get('FRSKY_ETHOS_SUITE_BIN')
        print("Entering post-deploy debug mode …")
        try:
            port = subprocess.check_output(
                [ethos_bin, '--serial', 'start'], text=True
            ).strip()
            print(f"Radio connected in debug mode on {port}")
            ser = serial.Serial(port=port)
            while True:
                try:
                    print(ser.readline().decode())
                except serial.serialutil.SerialException:
                    break
        except subprocess.CalledProcessError as e:
            print(f"Radio not connected: {e}")


if __name__ == "__main__":
    main()

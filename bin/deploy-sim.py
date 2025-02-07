import os
import shutil
import argparse
from tqdm import tqdm
import subprocess_conout
import serial
import subprocess
import ast

pbar = None

def copy_verbose(src, dst):
    pbar.update(1)
    shutil.copy(src,dst)

def count_files_in_tree(directory, extension = None):
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
        if os.path.exists(logs_folder) and not fileext == "fast":
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
                        shutil.copy(os.path.join(root, file), os.path.join(tgt_folder, file))

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
                except OSError as e:
                    print(f"Failed to delete entire folder, replacing single files instead")

            # Copy all files to the destination folder
            print(f"Copying all files to target in {dest}...")
            all_src = os.path.join(srcfolder, 'scripts', tgt)
            numFiles = count_files_in_tree(all_src)
            pbar = tqdm(total=numFiles)     
            shutil.copytree(all_src, tgt_folder, dirs_exist_ok=True, copy_function=copy_verbose)
            pbar.close()

        # Restore logs if not handled already
        if os.path.exists(logs_temp):
            print(f"Restoring logs from backup ...")
            os.makedirs(logs_folder, exist_ok=True)
            shutil.copytree(logs_temp, logs_folder, dirs_exist_ok=True)
            shutil.rmtree(logs_temp)

        print(f"Copy completed for: {dest}")
    if launch:
        cmd = (
            launch
        )
        ret = subprocess_conout.subprocess_conout(cmd, nrows=9999, encode=True)
        print(ret)
    print("Script execution completed.")

def main():
    parser = argparse.ArgumentParser(description='Deploy simulation files.')
    parser.add_argument('--src', type=str, help='Source folder')
    parser.add_argument('--sim' ,type=str, help='launch path for the sim after deployment')
    parser.add_argument('--fileext', type=str, help='File extension to filter by')
    parser.add_argument('--destfolders', type=str, default=None, help='Folders for deployment')
    parser.add_argument('--radio', action='store_true', default=None, help='Check radio connection')
    parser.add_argument('--radioDebug', action='store_true', default=None, help='Switch Radio to debug after deploying')
    parser.add_argument('--radioDebugOnly', action='store_true', default=None, help='Switch Radio to debug after deploying')

    args = parser.parse_args()

    if args.radio:
        if os.getenv('FRSKY_RADIO_TOOL_SRC') and not args.radioDebugOnly:
            # call radio_cmd.exe from FRSKY_RADIO_TOOL_SRC
            try:
                paths = subprocess.check_output(os.path.join(os.getenv('FRSKY_RADIO_TOOL_SRC'), 'radio_cmd.exe -s'), shell=True)
                paths = paths.decode("utf-8")
                paths = ast.literal_eval(paths)
                args.destfolders = os.path.join(paths['radio'],f'\\scripts')
            except subprocess.CalledProcessError as e:
                print(f"Radio not connected: {e}")   

    if not args.radioDebugOnly:             
        copy_files(args.src, args.fileext, launch = args.sim, destfolders = args.destfolders)

    if os.getenv('FRSKY_RADIO_TOOL_SRC'):
        if args.radio and args.radioDebug:
            if os.getenv('FRSKY_RADIO_TOOL_SRC'):
                try:
                    print("Entering Debug mode ...")
                    serialPortName = subprocess.check_output(os.path.join(os.getenv('FRSKY_RADIO_TOOL_SRC'), 'radio_cmd.exe -d'), shell=True)
                    serialPortName = serialPortName.decode("utf-8").rstrip()
                    print("Radio connected in debug mode ...")
                    ser = serial.Serial(port=serialPortName)
                    if serialPortName:
                        while True:
                            try:
                                print(ser.readline().decode("utf-8"))
                            except serial.serialutil.SerialException:
                                exit()
                except subprocess.CalledProcessError as e:
                    print(f"Radio not connected: {e}")

            

if __name__ == "__main__":
    main()
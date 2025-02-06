import os
import shutil
import argparse
from tqdm import tqdm
import subprocess_conout

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
        if os.path.exists(logs_folder):
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
    args = parser.parse_args()

    copy_files(args.src, args.fileext, launch = args.sim, destfolders = args.destfolders)

if __name__ == "__main__":
    main()
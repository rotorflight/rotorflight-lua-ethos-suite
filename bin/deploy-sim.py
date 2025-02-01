import os
import shutil
import subprocess
import argparse

def copy_files(src, fileext=None, launch=False, destfolders=None):
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

    for dest in destfolders:
        print(f"Processing destination folder: {dest}")

        logs_temp = os.path.join(dest, 'logs_temp')
        tgt_folder = os.path.join(dest, tgt)
        logs_folder = os.path.join(tgt_folder, 'logs')

        # Preserve the logs folder by moving it temporarily
        if os.path.exists(logs_folder):
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
                    shutil.rmtree(tgt_folder)
                    os.makedirs(tgt_folder, exist_ok=True)
                    if os.path.exists(logs_temp):
                        os.makedirs(logs_folder, exist_ok=True)
                        shutil.copytree(logs_temp, logs_folder, dirs_exist_ok=True)
                        shutil.rmtree(logs_temp)
                except OSError as e:
                    print(f"Failed to delete entire folder, replacing single files instead")

            # Copy all files to the destination folder
            all_src = os.path.join(srcfolder, 'scripts', tgt)
            shutil.copytree(all_src, tgt_folder, dirs_exist_ok=True)

        # Restore logs if not handled already
        if os.path.exists(logs_temp):
            os.makedirs(logs_folder, exist_ok=True)
            shutil.copytree(logs_temp, logs_folder, dirs_exist_ok=True)
            shutil.rmtree(logs_temp)

        print(f"Copy completed for: {dest}")
    if launch:
        subprocess.run(launch, check=True) 
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
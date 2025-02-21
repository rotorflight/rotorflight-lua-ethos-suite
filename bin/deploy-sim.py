import os
import shutil
import argparse
from tqdm import tqdm
import subprocess_conout
import serial
import serial.tools.list_ports
import subprocess
import time
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
        #todo: refactor this to use a platform independent approach
        ret = subprocess_conout.subprocess_conout(cmd, nrows=9999, encode=True)
        print(ret)
    print("Script execution completed.")


def checkEnvVar(var):
    if not os.getenv(var):
        print(f"Environment variable {var} not set.")
        return False
    return True

def CheckTools():
    if not checkEnvVar('FRSKY_SIM_BIN'):
        return False
    if not checkEnvVar('FRSKY_SIM_SRC'):        
        return False
    if not checkEnvVar('FRSKY_ETHOS_SUITE_BIN'):
        return False
    
    #check if paths do exist
    sim_bin_path = os.getenv('FRSKY_SIM_BIN')
    sim_src_path = os.getenv('FRSKY_SIM_SRC')
    ethos_suite_bin_path = os.getenv('FRSKY_ETHOS_SUITE_BIN')

    if not os.path.isfile(sim_bin_path):
        print(f"Simulator executable not found at {sim_bin_path}.")
        return False    
    if not os.path.isdir(sim_src_path):
        print(f"Simulator source folder not found at {sim_src_path}.")
        return False    
    if not os.path.isfile(ethos_suite_bin_path):
        print(f"Ethos Suite executable not found at {ethos_suite_bin_path}.")
        return False
    
    return True

import re

def extract_vid_pid(device_string):
    pattern = r'VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})'
    match = re.search(pattern, device_string)
    if match:
        vid = match.group(1)
        pid = match.group(2)
        return vid, pid
    else:
        return None, None
    
def getSerialPortByVidPid(vid, pid):
    reslt =  serial.tools.list_ports.comports()
    for d in reslt:
        usbInfo = d.hwid.split(" ")
        if(len(usbInfo) < 2):
            continue
        vid_pid = d.hwid.split(" ")[1]
        if vid_pid == "VID:PID="+vid+":"+pid:
            return d.device
    return None

def ethosSuiteParseRadioInfo(output, info):
    lines = output.splitlines()
    info['product'] = lines[3].split("|")[0].strip()
    info['usbinfo'] = lines[3].split("|")[1].strip()
    info['vid'], info['pid'] = extract_vid_pid(info['usbinfo'])
    return info

def waitForSerialPort(vid, pid):
    port = None
    cnt = 10
    while port == None:
        port = getSerialPortByVidPid(vid, pid)
        time.sleep(1)
        cnt -= 1
        if cnt == 0:
            return False
    return port

def ethosSuiteParsePath(output, info):
    lines = output.splitlines()
    if len(lines) < 8:
        info['debug'] = True
        return info
    else:
        info['debug'] = False
    info['bitmaps'] = lines[3].split("|")[1].strip()
    info['scripts'] = lines[4].split("|")[1].strip()
    info['screenshots'] = lines[5].split("|")[1].strip()
    info['audio'] = lines[6].split("|")[1].strip()
    info['i18n'] = lines[7].split("|")[1].strip()
    return info

def radioGetInfo(info):
    result = subprocess.run('"'+os.getenv('FRSKY_ETHOS_SUITE_BIN')+'"'+' --list-radio', text=True, capture_output=True, shell=True)
    if result.returncode != 0:
        return False
    info = ethosSuiteParseRadioInfo(result.stdout, info)
    result = subprocess.run('"'+os.getenv('FRSKY_ETHOS_SUITE_BIN')+'"'+' --radio-path', text=True, capture_output=True, shell=True)
    if result.returncode != 0:
        return False
    info = ethosSuiteParsePath(result.stdout , info)
    return info    

def main():
    #check if required tools are installed and env vars are set
    radio_info = {}
    radio_info["connected"] = False

    parser = argparse.ArgumentParser(description='Deploy simulation files.')
    parser.add_argument('--src', type=str, help='Source folder')
    parser.add_argument('--sim' ,type=str, help='launch path for the sim after deployment')
    parser.add_argument('--fileext', type=str, help='File extension to filter by')
    parser.add_argument('--radioDeploy', action='store_true', default=None, help='Deploy to radio')
    parser.add_argument('--radioDebug', action='store_true', default=None, help='Switch Radio to debug after deploying')

    if CheckTools() == False:
        print("Tools not installed or environment variables not set.")
        return

    args = parser.parse_args()

    if os.getenv('FRSKY_ETHOS_SUITE_BIN'):
        # call radio_cmd.exe from FRSKY_RADIO_TOOL_SRC
        result = radioGetInfo(radio_info)
        radio_info = result
        if result == False:
            print("Radio not connected")
        else: 
            print("Radio connected")
            radio_info["connected"] = True
            print(f"Radio product: {result['product']}") 

    if radio_info["connected"] and radio_info["debug"] and args.radioDeploy:
        subprocess.run('"'+os.getenv('FRSKY_ETHOS_SUITE_BIN')+'"'+' --serial stop', text=True, capture_output=True, shell=True)
        time.sleep(2)
        radio_info = radioGetInfo(radio_info)

    if args.radioDeploy and radio_info["connected"]:             
        copy_files(args.src, args.fileext, launch = args.sim, destfolders = args.destfolders)

    # rewrite this section to use ethos suite!
    if args.radioDebug:
        if os.getenv('FRSKY_ETHOS_SUITE_BIN'):
            # Eject radio volume
            try:
                if not radio_info["debug"]:
                    radio_volume = os.path.dirname(radio_info['scripts'])
                    #if os.name == 'nt':  # Windows
                        #subprocess.run(f'powershell -Command "Remove-Item -Path {radio_volume} -Recurse -Force"', shell=True, check=True)
                    #else:  # Unix-based systems
                        #subprocess.run(f"umount {radio_volume}", shell=True, check=True)
                    print("Radio volume ejected successfully.")
            except subprocess.CalledProcessError as e:
                print(f"Failed to eject radio volume: {e}")
            try:
                if radio_info["debug"]:
                    print("Radio already in debug mode ...")
                else:
                    print("Entering Debug mode ...")
                    subprocess.run('"'+os.getenv('FRSKY_ETHOS_SUITE_BIN')+'"'+' --serial start', text=True, capture_output=True, shell=True)
                port = getSerialPortByVidPid(radio_info['vid'], radio_info['pid'])
                result = waitForSerialPort(radio_info['vid'], radio_info['pid'])
                if result == False:
                    print("Failed to connect to radio")
                    return
                radio_info['port'] = result.rstrip()
                print("Radio connected in debug mode ...")
                ser = serial.Serial(port=radio_info["port"])
                if radio_info["port"]:
                    while True:
                        try:
                            print(ser.readline().decode("utf-8"))
                        except serial.serialutil.SerialException:
                            exit()
            except subprocess.CalledProcessError as e:
                print(f"Radio not connected: {e}")

            

if __name__ == "__main__":
    main()
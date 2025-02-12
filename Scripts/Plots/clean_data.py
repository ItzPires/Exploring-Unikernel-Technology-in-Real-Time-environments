import numpy as np
import re
import os
import threading
import sys

"""
Reads boot time data from a file, processes it, and saves it as a .npy file
"""
def get_clean_data_boot_time(file_path, filename, encoding):
    data = []

    with open(file_path, 'r', encoding=encoding) as f:
        # Process each line in the file
        for line in f:
            value = float(line)
            data.append(value)

    # Convert data to a numpy array
    data = np.array(data)

    # Convert data from seconds to milliseconds
    data = data * 1000

    # Save the processed data as a .npy file
    np.save(filename + ".npy", data)
    print(filename)

"""
Reads a file, processes each line to extract numeric values, and returns the data as a list
"""
def open_file_and_split(file_path, encoding):
    data = []

    with open(file_path, 'r', encoding=encoding) as f:
        # Process each line in the file
        for line in f:
            line = re.sub(r'[^0-9:]', '', line)  # Remove non-numeric characters except ":"
            parts = line.split(":")  # Split the line by ":"

            if len(parts) == 3:
                try:
                    value = int(parts[2])  # The third column contains the measured value
                    data.append(value)
                except ValueError:
                    continue
    return data

"""
Reads and processes data from a file, trims the initial 30 minutes, sorts the data, and saves it as a .npy file
"""
def get_clean_data(file_path, filename, encoding):
    try:
        data = open_file_and_split(file_path, encoding)
    except Exception as e:
        print(f"Error: {e}")
        data = open_file_and_split(file_path, "utf-16le")
    
    # Convert data to a numpy array
    data = np.array(data)

    # Remove the first 30 minutes of data
    total_time = 4 * 60  # Total time - 4 hours
    lines_to_remove = int((len(data) * 30) / total_time)  # Calculate the number of lines to remove
    data_trimmed = data[lines_to_remove:]  # Remove the first 30 minutes
    
    # Sort the data to remove a percentage from each side later
    sorted_data = np.sort(data_trimmed)

    # Save the processed data as a .npy file
    np.save(filename + ".npy", sorted_data)
    print(file_path)
"""
Processes files in a directory using multithreading.
"""
def process_files(option, directory, processing_function, encoding='utf-8'):
    threads = []

    # Walk through the directory
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".txt"):
                file_path = os.path.join(root, file)
                file_final_path = file_path.replace("RAW\\", "")
                final_name_path = file_final_path.replace(os.path.basename(file_final_path), "")

                if option == "cyclictest":
                    if "10000" in file_path:
                        final_name_path += "10000"
                    elif "1000" in file_path:
                        final_name_path += "1000"
                    elif "100" in file_path:
                        final_name_path += "100"
                    else:
                        final_name_path += "unknown"
                elif option == "boottime":
                    components_path = final_name_path.split("\\")[2].split("\\")
                    final_name_path += components_path[0]

                # Create a thread to process the file
                thread = threading.Thread(target=processing_function, args=(file_path, final_name_path, encoding))
                threads.append(thread)
                thread.start()

    # Wait for all threads to finish
    for t in threads:
        t.join()

"""
Main entry point of the script. Calls either `main` or `main2` based on the command-line argument.
    
Usage: python script.py [option]
    - option: "cyclictest" to process Cyclictest data or "boottime" to process BootTime data.
"""
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python script.py [option]")
        print("Options:")
        print("  cyclictest - Process Cyclictest data")
        print("  boottime   - Process BootTime data")
        sys.exit(1)

    option = sys.argv[1].lower()

    if option == "cyclictest":
        process_files(option, "../../../../DATA/Cyclictest/", get_clean_data)
    elif option == "boottime":
        process_files(option, "../../../../DATA/BootTime/", get_clean_data_boot_time)
    else:
        print(f"Invalid option: {option}")
        print("Valid options are 'cyclictest' or 'boottime'.")
        sys.exit(1)

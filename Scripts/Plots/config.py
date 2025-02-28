import numpy as np
import json
from matplotlib.colors import to_rgba

import stats
import jitter
import boxplot
import barchart_desvio

base_colors = {
    "BareMetal/Ubuntu": "#ADD8E6",      # Azul claro (lightblue)
    "Ubuntu": "#90EE90",          # Verde claro (lightgreen)
    "OSv": "#FFA07A",            # Laranja claro (light salmon)
    "Nanos": "#9370DB",          # Roxo claro (medium purple)
    "AppBox": "#D3D3D3",         # Amarelo claro (light yellow)
}

environment_hatches = {
    "ESXi": ".....",
    "QEMU": "\\\\",
    "Linux": "*"
}

path_types_of_tests = {
    "data": "../../DATA/",
    "latency": "/Cyclictest/",
    "boot": "/BootTime/",
    "cpu": "/CPU/",
    "memory": "/Memory/"
}

path_boxplots = "/Plots/"

X_LABEL = 'Source'
Y_LABEL_LATENCY = 'Latency (ms)'
Y_LABEL_BOOT = 'Boot Time (s)'

Y_LABEL_CPU = 'CPU (%)'
Y_LABEL_MEMORY = 'Memory (MB)'

LATENCY = 'latency'
BOOT = 'boot'
CPU = 'cpu'
MEMORY = 'memory'

LOG_APPENDIX_FILE = "_log"

function_map = {
    "1": "Process statistics",
    "2": "Process jitter",
    "3": "Generate boxplot",
    "4": "Generate barchart"
}

class BoxData:
    def __init__(self, data, source, color, stress, environment, label=""):
        self.data = data
        self.label = label
        self.color = color
        self.stress = stress
        self.source = source
        if "QEMU + KVM" in environment:
            self.environment = "QEMU"
        else:
            self.environment = environment

        if "Ubuntu" in label:
            self.label = "Ubuntu RT"

def load_data(filename, confidence_interval=10, type_data=LATENCY):
    data = np.load(filename)
    n = len(data)

    data = data/1000 #us to ms

    percentual_cute = confidence_interval/2
    corte = int(n * percentual_cute / 100)

    data_trimmed = data[corte: n - corte] # Remove {confidence_interval} of the data

    if type_data == CPU:
        data_trimmed = data_trimmed * 1000
    elif type_data == MEMORY:
        data_trimmed = data_trimmed * 1000 / 1024

    return data_trimmed

def from_json(json_file, confidence_interval, type_function):
    with open(json_file, "r") as file:
        profiles = json.load(file)
    
    for profile in profiles:
        try:
            process_profile(profile, confidence_interval, type_function)
        except Exception as e:
            print(f"Error: {e}")

def process_profile(profile, confidence_interval, type_function):
    title_name = profile["title"]
    type_data = profile["type"]
    all_data = []

    if type_data == LATENCY or type_data == BOOT or type_data == CPU or type_data == MEMORY:
        for i in range(len(profile["configurations"])):
            data = process_source(profile["configurations"][i], confidence_interval, type_data)
            all_data.append(data)
    else:
        print(f"Type {type_data} not supported")
        return

    if type_function == "1": # Process statistics
        for i in all_data:
            stats.get_stats(i)
    elif type_function == "2": # Process jitter
        jitter.plot(all_data, title_name)
    else: # Generate boxplot or barchart
        log = 0
        for i in range(2):  # Run twice to generate log and non-log plots
            log = not log
            if type_function == "3":
                boxplot.box_plot_all(all_data, title_name, log, type_data)
            elif type_function == "4":
                barchart_desvio.box_plot_all(all_data, title_name, log, type_data)
            else:
                print(f"Function {type_function} not supported")
                return
    
    print(f"{title_name} - Done")

def process_source(profile, confidence_interval, type_data):
    try:
        environment = profile["environment"]
        stress = profile["stress"]
        source = profile["source"]
        # if not exists, use source as label
        if "label" in profile:
            label = profile["label"]
        else:
            label = source
    
        if type_data == LATENCY:
            interval_range = profile["interval_range"]
            return get_profile(environment, stress, source, label, interval_range=interval_range, confidence_interval=confidence_interval, type_data=type_data) # Get profile
        elif type_data == BOOT:
            return get_profile(environment, stress, source, label, confidence_interval=confidence_interval, type_data=type_data) # Get profile
        elif type_data == CPU:
            return get_profile(environment, stress, source, label, confidence_interval=confidence_interval, type_data=type_data)
        elif type_data == MEMORY:
            return get_profile(environment, stress, source, label, confidence_interval=confidence_interval, type_data=type_data)
    except Exception as e:
        print(f"Error: {e}")

def get_profile(environment, stress, source, label, interval_range=10000, confidence_interval=10, type_data=LATENCY):
    if stress == False:
        stress_path = "NoStress"
    else:
        stress_path = "Stress"
    
    if environment == "QEMU + KVM":
        environment_path = "QEMU"
    else:
        environment_path = environment

    if "Old" in label:
        data = load_data(f"../OldData/{path_types_of_tests[type_data]}/{environment_path}/{stress_path}/{source}/{interval_range}.npy", confidence_interval, type_data)

    elif type_data == LATENCY:
        data = load_data(f"{path_types_of_tests['data']}/{path_types_of_tests[type_data]}/{environment_path}/{source}/{stress_path}/{interval_range}.npy", confidence_interval, type_data)
    elif type_data == BOOT:
        data = load_data(f"{path_types_of_tests['data']}/{path_types_of_tests[type_data]}/{environment_path}/{stress_path}/{source}/{environment_path}_{stress_path}_{source}.npy", confidence_interval, type_data)
    elif type_data == CPU or type_data == MEMORY:
        data = load_data(f"{path_types_of_tests['data']}/{path_types_of_tests[type_data]}/{environment_path}/{stress_path}/{source}/{source}.npy", confidence_interval, type_data)
        stress = False

    return BoxData(data, source, to_rgba(base_colors[source], alpha=1), stress, environment, label)

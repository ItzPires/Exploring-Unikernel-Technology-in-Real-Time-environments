import matplotlib.pyplot as plt
from matplotlib.patches import Patch
import numpy as np
import sys
import os

import config

def create_bar_chart(data, title, name_plot, log=False):
    nanos = [i for i in data if i.source == "Nanos"]
    osv = [i for i in data if i.source == "OSv"]
    appbox = [i for i in data if i.source == "AppBox"]
    ubuntu = [i for i in data if i.source == "Ubuntu"]

    #systems = list(range(1, 4))

    # Calculate standard deviation for ESXi and QEMU
    std_nanos_esxi = [np.mean(nanos[i].data) for i in range(len(nanos)) if i % 2 == 0]
    std_nanos_qemu = [np.mean(nanos[i].data) for i in range(len(nanos)) if i % 2 == 1]

    std_osv_esxi = [np.mean(osv[i].data) for i in range(len(osv)) if i % 2 == 0]
    std_osv_qemu = [np.mean(osv[i].data) for i in range(len(osv)) if i % 2 == 1]

    std_ubuntu_esxi = [np.mean(ubuntu[i].data) for i in range(len(ubuntu)) if i % 2 == 0]
    std_ubuntu_qemu = [np.mean(ubuntu[i].data) for i in range(len(ubuntu)) if i % 2 == 1]

    std_appbox_esxi = [np.mean(appbox[i].data) for i in range(len(appbox)) if i % 2 == 0]
    std_appbox_qemu = [np.mean(appbox[i].data) for i in range(len(appbox)) if i % 2 == 1]

    #profiles = ["B.3", "B.4"]
    profiles = ["10000 No Stress", "10000 Stress", "1000 No Stress", "1000 Stress", "100 No Stress", "100 Stress"]

    num_systems = len(profiles)
    x = np.arange(num_systems)  # Positions
    width = 0.1  # Narrower bars to fit 8 bars

    fig, ax = plt.subplots(figsize=(14, 8))
    if log:
        plt.yscale('log', base=10)

    # Add bars for ESXi and QEMU
    # Ajustar espaçamento
    # Ajustar espaçamento
    # Ajustar espaçamento entre os dois grupos
    # Ajustar espaçamento
    gap = width * 0  # Reduz o espaço entre os grupos

    a = 0

    for idx, profile in enumerate(profiles):
        center = x[idx]  # Posição central do grupo
        if(a == 0):
            a = 1
        else:
            center = x[idx] - 0.25
        
        # ESXi bars
        ax.bar(center - 2.5 * width + gap, std_nanos_esxi[idx], width,
            color=config.base_colors["Nanos"], hatch='\\\\', edgecolor='black',
            label='Nanos (ESXi)' if idx == 0 else "")
        ax.bar(center - 1.5 * width + gap, std_nanos_qemu[idx], width,
            color=config.base_colors["Nanos"], hatch=None, edgecolor='black',
            label='Nanos (QEMU)' if idx == 0 else "")

        ax.bar(center - 0.5 * width + gap, std_osv_esxi[idx], width,
            color=config.base_colors["OSv"], hatch='\\\\', edgecolor='black',
            label='OSv (ESXi)' if idx == 0 else "")
        ax.bar(center + 0.5 * width + gap, std_osv_qemu[idx], width,
            color=config.base_colors["OSv"], hatch=None, edgecolor='black',
            label='OSv (QEMU)' if idx == 0 else "")

        # Ubuntu bars (reduzindo a separação do grupo seguinte)
        ax.bar(center + 1.5 * width + gap, std_ubuntu_esxi[idx], width,
            color=config.base_colors["Ubuntu"], hatch='\\\\', edgecolor='black',
            label='Ubuntu RT (ESXi)' if idx == 0 else "")
        ax.bar(center + 2.5 * width + gap, std_ubuntu_qemu[idx], width,
            color=config.base_colors["Ubuntu"], hatch=None, edgecolor='black',
            label='Ubuntu RT (QEMU)' if idx == 0 else "")


    # Define legends
    nanos_patch = Patch(facecolor=config.base_colors["Nanos"], label='Nanos')
    osv_patch = Patch(facecolor=config.base_colors["OSv"], label='OSv')
    ubuntu_patch = Patch(facecolor=config.base_colors["Ubuntu"], label='Ubuntu RT')

    esxi_patch = Patch(edgecolor='black', facecolor='none', hatch='\\\\', label='ESXi')
    qemu_patch = Patch(edgecolor='black', facecolor='none', label='QEMU')

    #interval_patch_10000 = Patch(facecolor='gray', edgecolor='black', alpha=interval_alphas[10000], label='Interval: 10000')
    #interval_patch_1000 = Patch(facecolor='gray', edgecolor='black', alpha=interval_alphas[1000], label='Interval: 1000')
    #interval_patch_100 = Patch(facecolor='gray', edgecolor='black', alpha=interval_alphas[100], label='Interval: 100')

    #stress_legend = Patch(facecolor='silver', edgecolor='black', label='No Stress')
    #stress_legend2 = Patch(facecolor='silver', edgecolor='black', hatch='\\', label='With Stress')

    # Combine all legends
    all_legends = [
        nanos_patch, osv_patch, ubuntu_patch, esxi_patch, qemu_patch,
        #interval_patch_10000, interval_patch_1000, interval_patch_100,
        #stress_legend, stress_legend2
    ]

    ax.legend(handles=all_legends, loc='best', fontsize=12)

    # Add labels
    y_label = "Boot Time (s)"
    ax.set_ylabel(y_label, fontsize=20, fontweight='bold')  # Font size for Y-axis label
    #ax.set_xticks(x)
    ax.set_xticklabels(["Without Stress", "With Stress"], fontsize=20)  # Font size for X-tick labels
    ax.tick_params(axis='y', labelsize=20)  # Font size for Y-tick labels
    ax.grid(axis='y', linestyle='--')

    # Save and close
    plt.tight_layout()
    #save_path = os.path.join(config.path_types_of_tests['data'], "BootTime", "Plots", name_plot + ".png")

    # Verifica se o diretório existe, se não, cria o diretório
    #os.makedirs(os.path.dirname(save_path), exist_ok=True)

    # Salva a figura
    plt.savefig(config.path_types_of_tests['data'] + config.path_types_of_tests["latency"] + config.path_boxplots + name_plot + "jitter.png", dpi=300)
    plt.close()
    print(config.path_types_of_tests['data'] + config.path_types_of_tests["latency"] + config.path_boxplots + name_plot + "jitter.png")

def box_plot_all(data, title, log, type_data):
    name_plot = title.lower().replace(" ", "")
    if log:
        name_plot += config.LOG_APPENDIX_FILE

    #box_plot(data, name_plot, title, log, type_data)
    create_bar_chart(data, title, name_plot, log)

if __name__ == "__main__":
    confidence_interval = 5  # Default confidence interval

    if len(sys.argv) < 2:
        print("Usage: python file.py <file.json> [confidence_interval]")
        sys.exit(1)

    file_path = sys.argv[1]

    if len(sys.argv) > 2:
        try:
            confidence_interval = int(sys.argv[2])
        except ValueError:
            print("Confidence interval must be an integer.")
            sys.exit(1)

    config.from_json(file_path, confidence_interval, "4")

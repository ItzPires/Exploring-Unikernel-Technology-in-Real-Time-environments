import os
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
import sys
import numpy as np

import config

def box_plot(data_objects, name_plot, title, log, type_data):
    fig, ax = plt.subplots(figsize=(6, 4))
    #plt.title(title)
    #plt.xlabel(config.X_LABEL, fontweight='bold')
    #plt.xticks(rotation=90)
    if type_data == config.LATENCY:
        plt.ylabel(config.Y_LABEL_LATENCY, fontweight='bold')
    elif type_data == config.BOOT:
        plt.ylabel(config.Y_LABEL_BOOT, fontweight='bold')
    elif type_data == config.CPU:
        plt.ylabel(config.Y_LABEL_CPU, fontweight='bold')
    elif type_data == config.MEMORY:
        plt.ylabel(config.Y_LABEL_MEMORY, fontweight='bold')

    if log:
        plt.yscale('log', base=10)

    data = [obj.data for obj in data_objects]
    labels = [obj.label for obj in data_objects]
    stresses = [obj.stress for obj in data_objects]
    
    stress_legend_number = 0
    for i in range(len(stresses)):
        stress_legend_number += stresses[i]

    positions = [1, 1.7, 3, 3.7, 5, 5.7, 8, 8.7, 10, 10.7, 12, 12.7]
    #positions = [1, 1.6, 5, 5.6]
    #positions = np.arange(1, len(data) + 1)  # Posições dos boxplots

    boxplots = ax.boxplot(data, 
                           labels=labels,  # Ajustando as labels
                           showfliers=False,   # Ocultando outliers
                           showmeans=True,     # Mostrando a média
                           meanprops={"marker": "o", "markerfacecolor": "red", "markeredgecolor": "black"},  # Propriedades da média
                           whis=[0, 100],
                           patch_artist=True,#)#,
                           positions=positions)  # Permitir preenchimento das caixas


    # fill with colors
    # Criar uma lista para armazenar as legendas de ambiente únicas
    environment_legends = {}

    for patch, data_obj in zip(boxplots['boxes'], data_objects):
        # Aplicar a cor do objeto
        patch.set_facecolor(data_obj.color)

        # Obter a hachura correspondente ao ambiente
        hatch = config.environment_hatches[data_obj.environment]

        # Adicionar à legenda única, se ainda não estiver
        if data_obj.environment not in environment_legends:
            environment_legends[data_obj.environment] = Patch(
                facecolor='silver', edgecolor='black', hatch=hatch, label=data_obj.environment
            )

        # Aplicar a hachura, considerando stress
        if data_obj.stress:
            patch.set_hatch("////" + hatch)
        else:
            patch.set_hatch(hatch)

    mean_legend = Line2D([0], [0], marker='o', color='w', markerfacecolor='red', markersize=8, label='Mean')
    mode_legend = Line2D([0], [1], color='orange', linewidth=2, label='Median')
    stress_legend = Patch(facecolor='silver', edgecolor='black', label='No Stress')
    stress_legend2 = Patch(facecolor='silver', edgecolor='black', hatch='////', label='With Stress')

    if stress_legend_number == 0:
        stress_legends = [stress_legend]
    elif stress_legend_number == len(stresses):
        stress_legends = [stress_legend2]
    else:
        stress_legends = [stress_legend, stress_legend2]

    legends = [mean_legend, mode_legend] + stress_legends + list(environment_legends.values())

    plt.legend(handles=legends, loc='best')

    plt.tight_layout()
    #group_positions = [(0.25, "OSv"), (0.85, "Nanos")]  # Posições centrais e nomes dos grupos
    #ax.set_xticks(positions)  # Mostra os labels individuais
    #ax.set_xticklabels(labels, fontsize=10)  

    # Adicionando os labels dos grupos maiores
    #for pos, name in group_positions:
    #    fig.text(pos, 0.02, name, ha="center", fontsize=10, fontweight="bold")
    # show plot
    plt.savefig(config.path_types_of_tests['data'] + config.path_types_of_tests[type_data] + config.path_boxplots + name_plot + ".png", dpi=300)
    plt.close()
    print(config.path_types_of_tests['data'] + config.path_types_of_tests[type_data] + config.path_boxplots + name_plot + ".png")

def box_plot_all(data, title, log, type_data):
    name_plot = title.lower().replace(" ", "")
    if log:
        name_plot += config.LOG_APPENDIX_FILE

    box_plot(data, name_plot, title, log, type_data)

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

    config.from_json(file_path, confidence_interval, "3")

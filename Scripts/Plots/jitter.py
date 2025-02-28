import matplotlib.pyplot as plt
import numpy as np
import sys
import os

import config

def plot(all_data, title_name):
    data = []
    for i in all_data:
        data.append(np.std(i.data))
    # Barreiras de comparação em segundos
    barriers = {
        "1 µs": 0.001,
        "20 µs": 0.02,
        "100 µs": 0.1,
        "1 ms": 1,
        "2 ms": 2,
        "10 ms": 10,
        "20 ms": 20
    }
    colors = ["red", "blue", "green", "orange", "purple", "brown", "pink"]

    # Convertendo as barreiras para facilitar a plotagem
    barrier_values = list(barriers.values())
    barrier_labels = list(barriers.keys())


    # Índices para o gráfico de barras
    indices = np.arange(len(data))

    # Criar o gráfico
    plt.figure(figsize=(10, 6))
    plt.bar(indices, data, color="tan")

    # Adicionando linhas horizontais para as barreiras
    for value, label, color in zip(barrier_values, barrier_labels, colors):
        plt.axhline(y=value, color=color, linestyle="--", linewidth=1, label=f"{label}")

    # Rótulos e layout
    plt.xticks(indices, [f"C.{i+1}" for i in indices], rotation=90, fontsize=20)
    plt.yscale("log")  # Escala logarítmica para visualizar diferenças grandes
    plt.ylabel("Jitter (ms)", fontsize=20, fontweight='bold')
    plt.tick_params(axis='y', labelsize=20)
    #plt.xlabel("Profiles")
    #plt.title("Bar Chart with Jitter Data and Barriers")
    #plt.legend(loc="upper right", bbox_to_anchor=(1.3, 1))
    plt.legend(loc="upper right", fontsize=20)
    #plt.grid(axis="y", linestyle="--", linewidth=0.5)

    # Exibir o gráfico
    plt.tight_layout()
    plt.savefig(config.path_types_of_tests['data'] + config.path_types_of_tests["latency"] + config.path_boxplots + title_name + "jitter.png", dpi=300)
    plt.close()
    print(config.path_types_of_tests['data'] + config.path_types_of_tests["latency"] + config.path_boxplots + title_name + "jitter.png")
    plt.close()

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

    config.from_json(file_path, confidence_interval, "2")

import numpy as np
import sys

import config

"""Formats a value with a specific number of decimal places"""
def format_value(value, decimal_places=4):
    return f"{value:.{decimal_places}f}"

"""
Calculates and prints statistical metrics for a given dataset.

    :param data: The dataset containing the data to be analysed.
    :param decimal_places: The number of decimal places to format the output (default is 4).
"""
def get_stats(data, decimal_places=4):
    data_array = data.data # Extracts the data from the dataset
    
    # Calculating metrics
    mean = np.mean(data_array)  # Calculates the mean of the data
    median = np.median(data_array)  # Calculates the median of the data
    standard_deviation = np.std(data_array)  # Calculates the standard deviation of the data

    max_value = np.max(data_array)  # Maximum value in the data
    min_value = np.min(data_array)  # Minimum value in the data

    # Quartiles
    Q1 = np.percentile(data_array, 25)  # Calculates the first quartile
    Q3 = np.percentile(data_array, 75)  # Calculates the third quartile

    # Prints the results in a formatted table row
    print(
        f"& \\textbf{{{data.source}}} & "
        f"{format_value(mean, decimal_places)} & "
        f"{format_value(median, decimal_places)} & "
        f"{format_value(standard_deviation, decimal_places)} & "
        f"{format_value(Q1, decimal_places)} & "
        f"{format_value(Q3, decimal_places)} & "
        f"{format_value(min_value, decimal_places)} & "
        f"{format_value(max_value, decimal_places)} \\\\ \\cline{{2-9}}"
    )

"""
Main entry point of the script. Parses command-line arguments and initialises the configuration.
    
    Usage: python stats.py <file.json> [confidence_interval]
    - file.json: Path to the JSON file containing the dataset.
    - confidence_interval: Optional. The confidence interval to use (default is 5).
"""
if __name__ == "__main__":
    confidence_interval = 5  # Default confidence interval
    
    # Check if the required file path argument is provided
    if len(sys.argv) < 2:
        print("Usage: python stats.py <file.json> [confidence_interval]")
        sys.exit(1)

    file_path = sys.argv[1]  # Get the file path from the command-line arguments

    # Check if an optional confidence interval argument is provided
    if len(sys.argv) > 2:
        try:
            confidence_interval = int(sys.argv[2])  # Parse the confidence interval
        except ValueError:
            print("Confidence interval must be an integer.")
            sys.exit(1)

    # Initialise the configuration using the provided file and confidence interval
    config.from_json(file_path, confidence_interval, "1")

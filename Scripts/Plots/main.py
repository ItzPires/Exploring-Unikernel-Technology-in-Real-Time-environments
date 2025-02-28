import argparse
import textwrap

import config

def main():
    parser = argparse.ArgumentParser(
        description="Process data based on configuration.",
        formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument("file", help="Path to the JSON configuration file.")
    parser.add_argument("conf_int", type=int, help="Confidence interval as an integer (e.g., '5' for 5 percent).")
    parser.add_argument(
        "function",
        choices=config.function_map.keys(),
        help=textwrap.dedent("\n".join([f"- {k} : {v}" for k, v in config.function_map.items()]))
    )

    args = parser.parse_args()
    print(f"Executing: {config.function_map[args.function]}...")
    config.from_json(args.file, args.conf_int, args.function)

if __name__ == "__main__":
    main()

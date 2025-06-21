import re
import matplotlib.pyplot as plt
from collections import defaultdict
import numpy as np
import os
import math


def parse_file(filename):
    with open(filename, 'r') as f:
        content = f.read()

    implementations = content.split('----------------------------')
    data = defaultdict(lambda: defaultdict(lambda: defaultdict(dict)))

    for impl in implementations:
        if not impl.strip():
            continue

        # Extract implementation name and size
        impl_match = re.search(r'Implementation: (.+?) \((\d+) Kbits\)', impl)
        if not impl_match:
            impl_match = re.search(r'Implementation: (.+?) \( Kbits\)', impl)
            if impl_match:
                impl_name = impl_match.group(1).strip()
                size = 'N/A'
            else:
                continue
        else:
            impl_name = impl_match.group(1).strip()
            size = impl_match.group(2)

        # Extract benchmarks data
        benchmarks = re.findall(r'([a-zA-Z\-]+)\s*IPC:\s*([\d.]+)\s*Ratio of branch misses:\s*([\d.]+)\s*%', impl)

        for bench, ipc, miss in benchmarks:
            data[bench][impl_name][size] = {
                'ipc': float(ipc),
                'miss': float(miss)
            }

    return data


def get_effective_size(impl_name, nominal_size):
    """Calculate effective size by adding history register bits"""
    nominal_size = int(nominal_size)

    if "Gshare" in impl_name:
        # Gshare implementations
        gbp_entries = {
            '32': 16384,  # 32Kbits -> 16K entries
            '64': 32768,  # 64Kbits -> 32K entries
            '128': 65536,  # 128Kbits -> 64K entries
            '256': 131072,  # 256Kbits -> 128K entries
            '512': 262144  # 512Kbits -> 256K entries
        }
        history_bits = math.log2(gbp_entries[str(nominal_size)])
        return nominal_size + history_bits / 1024  # Convert bits to Kbits

    elif "Tournament" in impl_name:
        # Tournament implementations
        gbp_entries = {
            '32': 4096,  # 32Kbits -> 4K entries
            '64': 16384,  # 64Kbits -> 16K entries
            '128': 8192,  # 128Kbits -> 8K entries
            '256': 16384,  # 256Kbits -> 16K entries
            '512': 32768  # 512Kbits -> 32K entries
        }
        history_bits = math.log2(gbp_entries[str(nominal_size)])
        return nominal_size + history_bits / 1024.0  # Convert bits to Kbits

    elif "TAGE" in impl_name:
        # TAGE has fixed 256-bit global history
        return nominal_size + 256 / 1024.0  # Convert 256 bits to Kbits

    # For other implementations (Bimodal, Local), use nominal size
    return nominal_size


def create_plots(data):
    # Create output directory if it doesn't exist
    os.makedirs('benchmark_plots', exist_ok=True)

    benchmarks = sorted(data.keys())
    nominal_sizes = ['32', '64', '128', '256', '512']
    implementations = set()

    # Get all unique implementations
    for bench in data:
        implementations.update(data[bench].keys())
    implementations = sorted(implementations)

    # Color and marker setup
    colors = plt.cm.tab20(np.linspace(0, 1, len(implementations)))
    markers = ['o', 's', '^', 'D', 'v', '>', '<', 'p', '*', 'h', 'H', '+', 'x', 'X', 'd', '|', '_']

    for bench in benchmarks:
        # IPC Plot
        plt.figure(figsize=(12, 6))
        for i, impl in enumerate(implementations):
            if impl not in data[bench]:
                continue

            x = []
            y = []
            for size in nominal_sizes:
                if size in data[bench][impl]:
                    effective_size = get_effective_size(impl, size)
                    x.append(effective_size)
                    y.append(data[bench][impl][size]['ipc'])

            if x and y:  # Only plot if we have data
                plt.plot(x, y,
                         label=impl,
                         color=colors[i],
                         marker=markers[i % len(markers)],
                         linestyle='-',
                         linewidth=2,
                         markersize=8)

        plt.title(f'IPC de {bench.upper()}', fontsize=14)
        plt.xlabel('Presupuesto (Kbits)', fontsize=12)
        plt.ylabel('IPC', fontsize=12)
        plt.grid(True, linestyle='--', alpha=0.7)

        # Set x-ticks to show nominal sizes
        plt.xticks([32, 64, 128, 256, 512], nominal_sizes)

        plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        plt.tight_layout()
        plt.savefig(f'benchmark_plots/{bench}_ipc.png', dpi=300, bbox_inches='tight')
        plt.close()

        # Branch Miss Rate Plot
        plt.figure(figsize=(12, 6))
        for i, impl in enumerate(implementations):
            if impl not in data[bench]:
                continue

            x = []
            y = []
            for size in nominal_sizes:
                if size in data[bench][impl]:
                    effective_size = get_effective_size(impl, size)
                    x.append(effective_size)
                    y.append(data[bench][impl][size]['miss'])

            if x and y:  # Only plot if we have data
                plt.plot(x, y,
                         label=impl,
                         color=colors[i],
                         marker=markers[i % len(markers)],
                         linestyle='-',
                         linewidth=2,
                         markersize=8)

        plt.title(f'Tasa de Fallos de {bench.upper()}', fontsize=14)
        plt.xlabel('Presupuesto (Kbits)', fontsize=12)
        plt.ylabel('Tasa de Fallos (%)', fontsize=12)
        plt.grid(True, linestyle='--', alpha=0.7)

        # Set x-ticks to show nominal sizes
        plt.xticks([32, 64, 128, 256, 512], nominal_sizes)

        plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        plt.tight_layout()
        plt.savefig(f'benchmark_plots/{bench}_miss_rate.png', dpi=300, bbox_inches='tight')
        plt.close()


# Example usage
data = parse_file('stats_bp.txt')
create_plots(data)
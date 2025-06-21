import re
import matplotlib.pyplot as plt
from collections import defaultdict
import numpy as np
import os
from scipy.stats import hmean


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


def create_size_comparison_plots(data):
    # Create output directories if they don't exist
    os.makedirs('size_comparison_plots/png', exist_ok=True)
    os.makedirs('size_comparison_plots/eps', exist_ok=True)

    benchmarks = sorted(data.keys())
    implementations = sorted({impl for bench in data for impl in data[bench]})
    sizes = ['32', '64', '128', '256', '512']

    # Color setup
    colors = plt.cm.tab20(np.linspace(0, 1, len(implementations) + 1))  # +1 for average bar

    # Set style for publication-quality plots
    plt.style.use('seaborn-v0_8-deep')
    plt.rcParams.update({
        'font.size': 12,
        'axes.titlesize': 14,
        'axes.labelsize': 12,
        'xtick.labelsize': 10,
        'ytick.labelsize': 10,
        'legend.fontsize': 10,
        'figure.dpi': 300,
        'savefig.dpi': 300,
        'savefig.bbox': 'tight',
        'savefig.pad_inches': 0.1,
        'lines.linewidth': 1.5,
        'axes.grid': True,
        'grid.alpha': 0.3
    })

    # Create plots for each size
    for size in sizes:
        # IPC Plot for this size
        plt.figure(figsize=(14, 6))  # Slightly wider to accommodate average bar

        x = np.arange(len(benchmarks) + 1)  # +1 for average position
        width = 0.15
        multiplier = 0

        # Calculate harmonic means for IPC
        ipc_hmeans = {impl: 0 for impl in implementations}
        valid_counts = {impl: 0 for impl in implementations}

        for impl in implementations:
            ipc_values = []
            for bench in benchmarks:
                if impl in data[bench] and size in data[bench][impl]:
                    ipc_values.append(data[bench][impl][size]['ipc'])

            if ipc_values:
                ipc_hmeans[impl] = hmean(ipc_values)
                valid_counts[impl] = len(ipc_values)

        for impl in implementations:
            ipc_values = []
            for bench in benchmarks:
                if impl in data[bench] and size in data[bench][impl]:
                    ipc_values.append(data[bench][impl][size]['ipc'])
                else:
                    ipc_values.append(0)

            # Add average at the end
            if valid_counts[impl] > 0:
                ipc_values.append(ipc_hmeans[impl])
            else:
                ipc_values.append(0)

            offset = width * multiplier
            plt.bar(x + offset, ipc_values, width, label=impl, color=colors[multiplier])
            multiplier += 1

        # Add benchmark labels + "Average"
        bench_labels = benchmarks + ['Average']

        plt.title(f'IPC Comparison ({size}Kbits) with Harmonic Mean', fontsize=14)
        plt.xlabel('Benchmarks', fontsize=12)
        plt.ylabel('IPC', fontsize=12)
        plt.xticks(x + width * (multiplier - 1) / 2, bench_labels, rotation=45, ha='right')
        plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        plt.grid(True, axis='y', linestyle='--', alpha=0.3)
        plt.tight_layout()

        # Save in both formats
        plt.savefig(f'size_comparison_plots/png/ipc_{size}K.png')
        plt.savefig(f'size_comparison_plots/eps/ipc_{size}K.eps', format='eps')
        plt.close()

        # Miss Rate Plot for this size
        plt.figure(figsize=(14, 6))

        multiplier = 0

        # Calculate arithmetic means for miss rate
        miss_means = {impl: 0 for impl in implementations}
        valid_counts = {impl: 0 for impl in implementations}

        for impl in implementations:
            miss_values = []
            for bench in benchmarks:
                if impl in data[bench] and size in data[bench][impl]:
                    miss_values.append(data[bench][impl][size]['miss'])

            if miss_values:
                miss_means[impl] = np.mean(miss_values)
                valid_counts[impl] = len(miss_values)

        for impl in implementations:
            miss_values = []
            for bench in benchmarks:
                if impl in data[bench] and size in data[bench][impl]:
                    miss_values.append(data[bench][impl][size]['miss'])
                else:
                    miss_values.append(0)

            # Add average at the end
            if valid_counts[impl] > 0:
                miss_values.append(miss_means[impl])
            else:
                miss_values.append(0)

            offset = width * multiplier
            plt.bar(x + offset, miss_values, width, label=impl, color=colors[multiplier])
            multiplier += 1

        plt.title(f'Branch Miss Rate Comparison ({size}Kbits) with Arithmetic Mean', fontsize=14)
        plt.xlabel('Benchmarks', fontsize=12)
        plt.ylabel('Miss Rate (%)', fontsize=12)
        plt.xticks(x + width * (multiplier - 1) / 2, bench_labels, rotation=45, ha='right')
        plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        plt.grid(True, axis='y', linestyle='--', alpha=0.3)
        plt.tight_layout()

        # Save in both formats
        plt.savefig(f'size_comparison_plots/png/miss_rate_{size}K.png')
        plt.savefig(f'size_comparison_plots/eps/miss_rate_{size}K.eps', format='eps')
        plt.close()


# Example usage
data = parse_file('stats_bp.txt')
create_size_comparison_plots(data)
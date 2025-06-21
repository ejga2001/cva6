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

        benchmarks = re.findall(r'([a-zA-Z\-]+)\s*IPC:\s*([\d.]+)\s*Ratio of branch misses:\s*([\d.]+)\s*%', impl)

        for bench, ipc, miss in benchmarks:
            data[bench][impl_name][size] = {
                'ipc': float(ipc),
                'miss': float(miss)
            }

    return data

def create_mean_comparison_plots(data):
    os.makedirs('mean_comparison_plots/png', exist_ok=True)
    os.makedirs('mean_comparison_plots/eps', exist_ok=True)

    implementations = sorted({impl for bench in data for impl in data[bench]})
    sizes = ['32', '64', '128', '256', '512']

    # Color setup
    colors = plt.cm.tab20(np.linspace(0, 1, len(implementations)))

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

    # IPC Mean Plot
    plt.figure(figsize=(10, 6))

    x = np.arange(len(sizes))
    width = 0.15
    multiplier = 0

    for impl in implementations:
        ipc_means = []
        for size in sizes:
            ipc_values = []
            for bench in data:
                if impl in data[bench] and size in data[bench][impl]:
                    ipc_values.append(data[bench][impl][size]['ipc'])

            if ipc_values:
                ipc_means.append(hmean(ipc_values))
            else:
                ipc_means.append(0)

        offset = width * multiplier
        plt.bar(x + offset, ipc_means, width, label=impl, color=colors[multiplier])
        multiplier += 1

    plt.title('Harmonic Mean IPC Across All Benchmarks', fontsize=14)
    plt.xlabel('Predictor Size (Kbits)', fontsize=12)
    plt.ylabel('Harmonic Mean IPC', fontsize=12)
    plt.xticks(x + width * (multiplier - 1) / 2, sizes)
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.grid(True, axis='y', linestyle='--', alpha=0.3)
    plt.tight_layout()

    plt.savefig('mean_comparison_plots/png/ipc_mean_comparison.png')
    plt.savefig('mean_comparison_plots/eps/ipc_mean_comparison.eps', format='eps')
    plt.close()

    # Miss Rate Mean Plot
    plt.figure(figsize=(10, 6))

    multiplier = 0

    for impl in implementations:
        miss_means = []
        for size in sizes:
            miss_values = []
            for bench in data:
                if impl in data[bench] and size in data[bench][impl]:
                    miss_values.append(data[bench][impl][size]['miss'])

            if miss_values:
                miss_means.append(np.mean(miss_values))
            else:
                miss_means.append(0)

        offset = width * multiplier
        plt.bar(x + offset, miss_means, width, label=impl, color=colors[multiplier])
        multiplier += 1

    plt.title('Arithmetic Mean Miss Rate Across All Benchmarks', fontsize=14)
    plt.xlabel('Predictor Size (Kbits)', fontsize=12)
    plt.ylabel('Mean Miss Rate (%)', fontsize=12)
    plt.xticks(x + width * (multiplier - 1) / 2, sizes)
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.grid(True, axis='y', linestyle='--', alpha=0.3)
    plt.tight_layout()

    plt.savefig('mean_comparison_plots/png/miss_rate_mean_comparison.png')
    plt.savefig('mean_comparison_plots/eps/miss_rate_mean_comparison.eps', format='eps')
    plt.close()

# Example usage
data = parse_file('stats_bp.txt')
create_mean_comparison_plots(data)
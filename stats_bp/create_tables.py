import re
from collections import defaultdict
from statistics import harmonic_mean

def parse_file(filename):
    with open(filename, 'r') as f:
        content = f.read()

    implementations = content.split('----------------------------')
    data = defaultdict(lambda: defaultdict(dict))

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
            data[impl_name][size][bench] = {
                'ipc': float(ipc),
                'miss': float(miss)
            }

    return data

def generate_latex_tables(data):
    benchmarks = ['bfs', 'cutcp', 'histo', 'lbm', 'mri-gridding', 'mri-q',
                  'sad', 'sgemm', 'spmv', 'stencil', 'tpacf']
    sizes = ['32', '64', '128', '256', '512']

    for impl_name in data:
        # Skip implementations with no size information
        if 'N/A' in data[impl_name]:
            continue

        # Branch Misses Table (unchanged)
        print(f"\\begin{{table}}[H]")
        print(f"    \\centering")
        print(f"    \\resizebox{{\\linewidth}}{{!}}{{")
        print(f"        \\begin{{tabular}}{{|c|c|c|c|c|c|c|c|c|c|c|c|c|}}")
        print(f"            \\hline")
        print(f"             \\rowcolor{{gray!60}}")
        print(f"             \\textbf{{Tamaño}} & \\multicolumn{{11}}{{|c|}}{{\\textbf{{Tasa de fallos (\\%)}}}} \\\\")
        print(f"             \\cline{{2-12}}")
        print(f"              \\rowcolor{{gray!60}}")
        print(f"              \\textbf{{(Kbits)}} & \\textbf{{bfs}} & \\textbf{{cutcp}} & \\textbf{{histo}} & \\textbf{{lbm}} & \\textbf{{mri-gridding}} & \\textbf{{mri-q}} & \\textbf{{sad}} & \\textbf{{sgemm}} & \\textbf{{spmv}} & \\textbf{{stencil}} & \\textbf{{tpacf}} \\\\ ")
        print(f"              \\hline")

        # Calculate averages for each size
        size_averages = defaultdict(list)

        for size in sizes:
            if size not in data[impl_name]:
                continue

            print(f"              \\textbf{{{size}}} ", end="")
            for bench in benchmarks:
                if bench in data[impl_name][size]:
                    print(f"& {data[impl_name][size][bench]['miss']:.2f} ", end="")
                    size_averages[size].append(data[impl_name][size][bench]['miss'])
                else:
                    print("& - ", end="")
            print("\\\\")
            print(f"              \\hline")

        # Calculate overall averages (arithmetic mean for misses)
        print(f"              \\cellcolor{{gray!60}} \\textbf{{Media}} ", end="")
        for bench in benchmarks:
            bench_values = []
            for size in sizes:
                if size in data[impl_name] and bench in data[impl_name][size]:
                    bench_values.append(data[impl_name][size][bench]['miss'])
            if bench_values:
                avg = sum(bench_values) / len(bench_values)
                print(f"& {avg:.2f} ", end="")
            else:
                print("& - ", end="")
        print("\\\\")
        print(f"              \\hline")

        print(f"        \\end{{tabular}}")
        print(f"    }}")
        print(f"    \\caption{{Tasa de fallos de predicción para cada tamaño para la implementación \\textbf{{{impl_name}}}}}")
        print(f"    \\label{{branch-misses-{impl_name.lower().replace(' ', '-')}}}")
        print(f"\\end{{table}}")
        print()

        # IPC Table
        print(f"\\begin{{table}}[H]")
        print(f"    \\centering")
        print(f"    \\resizebox{{\\linewidth}}{{!}}{{")
        print(f"        \\begin{{tabular}}{{|c|c|c|c|c|c|c|c|c|c|c|c|c|}}")
        print(f"            \\hline")
        print(f"             \\rowcolor{{gray!60}}")
        print(f"             \\textbf{{Tamaño}} & \\multicolumn{{11}}{{|c|}}{{\\textbf{{IPC}}}} \\\\")
        print(f"             \\cline{{2-12}}")
        print(f"              \\rowcolor{{gray!60}}")
        print(f"              \\textbf{{(Kbits)}} & \\textbf{{bfs}} & \\textbf{{cutcp}} & \\textbf{{histo}} & \\textbf{{lbm}} & \\textbf{{mri-gridding}} & \\textbf{{mri-q}} & \\textbf{{sad}} & \\textbf{{sgemm}} & \\textbf{{spmv}} & \\textbf{{stencil}} & \\textbf{{tpacf}} \\\\ ")
        print(f"              \\hline")

        for size in sizes:
            if size not in data[impl_name]:
                continue

            print(f"              \\textbf{{{size}}} ", end="")
            for bench in benchmarks:
                if bench in data[impl_name][size]:
                    print(f"& {data[impl_name][size][bench]['ipc']:.2f} ", end="")
                else:
                    print("& - ", end="")
            print("\\\\")
            print(f"              \\hline")

        # Calculate harmonic mean for IPC values
        print(f"              \\cellcolor{{gray!60}} \\textbf{{Media}} ", end="")
        for bench in benchmarks:
            bench_values = []
            for size in sizes:
                if size in data[impl_name] and bench in data[impl_name][size]:
                    bench_values.append(data[impl_name][size][bench]['ipc'])
            if bench_values:
                try:
                    hmean = harmonic_mean(bench_values)
                    print(f"& {hmean:.2f} ", end="")
                except statistics.StatisticsError:
                    print("& - ", end="")
            else:
                print("& - ", end="")
        print("\\\\")
        print(f"              \\hline")

        print(f"        \\end{{tabular}}")
        print(f"    }}")
        print(f"    \\caption{{IPC para cada tamaño para la implementación \\textbf{{{impl_name}}}}}")
        print(f"    \\label{{ipc-{impl_name.lower().replace(' ', '-')}}}")
        print(f"\\end{{table}}")
        print()

# Example usage
data = parse_file('stats_bp.txt')
generate_latex_tables(data)
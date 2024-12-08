import json
from itertools import product

def is_power_of_two(value):
    """Verifica si un número es potencia de 2."""
    return (value & (value - 1)) == 0 and value > 0

def generate_combinations(vlen, nr_entries, instr_per_fetch):
    """
    Genera todas las combinaciones de entrada para el módulo gbp con parámetros configurables.

    :param vlen: Longitud de `vpc_i` en bits.
    :param nr_entries: Número de entradas (potencia de 2).
    :param instr_per_fetch: Cantidad de instrucciones por fetch (potencia de 2).
    :return: Lista de combinaciones binarias para cada entrada.
    """
    # Validar que NR_ENTRIES e INSTR_PER_FETCH sean potencias de 2
    if not (is_power_of_two(nr_entries) and is_power_of_two(instr_per_fetch)):
        raise ValueError("NR_ENTRIES e INSTR_PER_FETCH deben ser potencias de 2.")

    # Crear combinaciones para `vpc_i` excluyendo el bit menos significativo
    vpc_bits = vlen - 1  # Excluir LSB
    vpc_combinations = [f"{x:0{vpc_bits}b}" for x in range(2**vpc_bits)]

    # Crear combinaciones para otros inputs
    other_inputs = {
        "bht_update_i_valid": 1,  # 1 bit
        "bht_update_i_taken": 1  # 1 bit
    }
    other_combinations = list(product(*[range(2**bits) for bits in other_inputs.values()]))

    # Crear todas las combinaciones finales
    input_combinations = []
    for vpc in vpc_combinations:
        for other in other_combinations:
            combination = {
                "vpc_i": str(vpc) + "0",
                "bht_update_i_valid": other[0],
                "bht_update_i_taken": other[1],
                "flush_bp_i": 0,  # Siempre 0
                "debug_mode_i": 0,  # Siempre 0
                "nr_entries": nr_entries,
                "instr_per_fetch": instr_per_fetch
            }
            input_combinations.append(combination)

    return input_combinations

def main():
    # Configuración (modificar directamente aquí)
    VLEN = 4  # Número de bits de vpc_i
    NR_ENTRIES = 8  # Número de entradas (potencia de 2)
    INSTR_PER_FETCH = 2  # Instrucciones por fetch (potencia de 2)

    # Generar combinaciones
    try:
        combinations = generate_combinations(VLEN, NR_ENTRIES, INSTR_PER_FETCH)
        # Guardar resultados en un archivo JSON
        output_file = "gbp_combinations.json"
        with open(output_file, "w") as file:
            # Escribir las entradas en el orden correcto
            json.dump(combinations, file, indent=4, sort_keys=False)
        print(f"Se generaron {len(combinations)} combinaciones y se guardaron en '{output_file}'.")
    except ValueError as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()

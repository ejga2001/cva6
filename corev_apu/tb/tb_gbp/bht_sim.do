# Script ModelSim: bimodal_bht_sim.do
# Crea proyecto, simula hasta $finish y guarda VCD

# 1. Configurar entorno y crear proyecto
quit -sim
file mkdir ./bimodal_bht_work
project new ./bimodal_bht_work bimodal_bht_project

# 2. Añadir archivos al proyecto
project addfile $env(CVA6_REPO)/core/include/riscv_pkg.sv
project addfile $env(CVA6_REPO)/core/include/config_pkg.sv
project addfile $env(CVA6_REPO)/core/include/cv64a6_imafdc_sv39_config_pkg.sv
project addfile $env(CVA6_REPO)/core/include/build_config_pkg.sv
project addfile $env(CVA6_REPO)/core/include/ariane_pkg.sv
project addfile $env(CVA6_REPO)/vendor/pulp-platform/fpga-support/rtl/AsyncThreePortRam.sv
project addfile $env(CVA6_REPO)/core/frontend/bht.sv
project addfile ../hdl/bht_tb.sv

# 3. Compilar fuentes (orden crítico)
vlog -sv $env(CVA6_REPO)/core/include/riscv_pkg.sv
vlog -sv $env(CVA6_REPO)/core/include/config_pkg.sv
vlog -sv $env(CVA6_REPO)/core/include/cv64a6_imafdc_sv39_config_pkg.sv
vlog -sv $env(CVA6_REPO)/core/include/build_config_pkg.sv
vlog -sv $env(CVA6_REPO)/core/include/ariane_pkg.sv
vlog -sv $env(CVA6_REPO)/vendor/pulp-platform/fpga-support/rtl/AsyncThreePortRam.sv
vlog -sv $env(CVA6_REPO)/core/frontend/bht.sv
vlog -sv ../hdl/bht_tb.sv

# 4. Iniciar simulación
vsim -voptargs="+acc" work.bht_tb

# 5. Configurar captura de señales
log -r /*

# 6. Ejecutar simulación completa (hasta $finish)
run -all

# 7. Guardar ondas en VCD
vcd file ondas_bht.vcd
vcd add /bht_tb/*
vcd flush  # Forzar escritura

# 8. Cerrar proyecto y salir
project close
quit -force

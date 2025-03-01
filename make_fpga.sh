#!/bin/bash

BRANCH_PRED_IMPL_NAMES=("bht" "gbp" "lbp" "tournament")
BHT_CONFIGS=("8192" "16384" "32768" "65536" "131072")
GLOBAL_CONFIGS=("8192" "16384" "32768" "65536" "131072")
LOCAL_CONFIGS=("4096-4096" "8192-8192" "16384-16384" "32768-32768" "65536-65536")
TOURNAMENT_CONFIGS=("2048-2048-2048-2048" "4096-4096-4096-4096" "8192-8192-8192-8192" \
                    "16384-16384-16384-16384" "32768-32768-32768-32768")
ALL_CONFIGS=("BHT_CONFIGS" "GLOBAL_CONFIGS" "LOCAL_CONFIGS" "TOURNAMENT_CONFIGS")

export BOARD=$1
export XILINX_PART=$2
export XILINX_BOARD=$3
export CLK_PERIOD_NS=$4

generate_bitstream_bht() {
    impl=$1
    impl_name=$2
    bht_entries=$3
    fpga_tmp=$(mktemp -d)

    cp -Rf common $fpga_tmp
    cp -Rf core $fpga_tmp
    cp -Rf corev_apu $fpga_tmp
    cp -Rf vendor $fpga_tmp

    make -C $fpga_tmp/corev_apu/fpga bit_${impl_name} BOARD=$BOARD \
                               XILINX_PART=$XILINX_PART \
                               XILINX_BOARD=$XILINX_BOARD \
                               CLK_PERIOD_NS=$CLK_PERIOD_NS \
                               BRANCH_PRED_IMPL=${impl} \
                               BHT_ENTRIES=${bht_entries}

    if [ $? -ne 0 ]; then
        echo "Error: MAKE command failed for BRANCH_PRED_IMPL=${impl_name}"
        rm -Rf $fpga_tmp
        exit 1
    fi

    suffix_name=${impl}_"bht=${bht_entries}"

    cp -Rf $fpga_tmp/corev_apu/fpga/work-fpga/ariane_xilinx.bit corev_apu/fpga/bitstreams/ariane_xilinx_${suffix_name}.bit
    cp -Rf $fpga_tmp/corev_apu/fpga/ariane.xpr corev_apu/fpga/xilinx_projects/ariane_${suffix_name}.xpr
    cp -Rf $fpga_tmp/corev_apu/fpga/vivado.log corev_apu/fpga/logs/vivado_${suffix_name}.log
    rm -Rf $fpga_tmp
}

generate_bitstream_gbp() {
    impl=$1
    impl_name=$2
    gbp_entries=$3

    fpga_tmp=$(mktemp -d)

    cp -Rf common $fpga_tmp
    cp -Rf core $fpga_tmp
    cp -Rf corev_apu $fpga_tmp
    cp -Rf vendor $fpga_tmp

    make -C $fpga_tmp/corev_apu/fpga bit_${impl_name} BOARD=$BOARD \
                               XILINX_PART=$XILINX_PART \
                               XILINX_BOARD=$XILINX_BOARD \
                               CLK_PERIOD_NS=$CLK_PERIOD_NS \
                               BRANCH_PRED_IMPL=${impl} \
                               GBP_ENTRIES=${gbp_entries}

    if [ $? -ne 0 ]; then
        echo "Error: MAKE command failed for BRANCH_PRED_IMPL=${impl_name}"
        rm -Rf $fpga_tmp
        exit 1
    fi

    suffix_name=${impl}_"gbp=${gbp_entries}"

    cp -Rf $fpga_tmp/corev_apu/fpga/work-fpga/ariane_xilinx.bit corev_apu/fpga/bitstreams/ariane_xilinx_${suffix_name}.bit
    cp -Rf $fpga_tmp/corev_apu/fpga/ariane.xpr corev_apu/fpga/xilinx_projects/ariane_${suffix_name}.xpr
    cp -Rf $fpga_tmp/corev_apu/fpga/vivado.log corev_apu/fpga/logs/vivado_${suffix_name}.log
    rm -Rf $fpga_tmp
}

generate_bitstream_lbp() {
    impl=$1
    impl_name=$2
    lbp_entries=$(echo "$3" | tr "-" " " | cut -d " " -f1,1)
    lhr_entries=$(echo "$3" | tr "-" " " | cut -d " " -f2,2)

    fpga_tmp=$(mktemp -d)

    cp -Rf common $fpga_tmp
    cp -Rf core $fpga_tmp
    cp -Rf corev_apu $fpga_tmp
    cp -Rf vendor $fpga_tmp

    make -C $fpga_tmp/corev_apu/fpga bit_${impl_name} BOARD=$BOARD \
                               XILINX_PART=$XILINX_PART \
                               XILINX_BOARD=$XILINX_BOARD \
                               CLK_PERIOD_NS=$CLK_PERIOD_NS \
                               BRANCH_PRED_IMPL=${impl} \
                               LBP_ENTRIES=${lbp_entries} \
                               LHR_ENTRIES=${lhr_entries}

    if [ $? -ne 0 ]; then
        echo "Error: MAKE command failed for BRANCH_PRED_IMPL=${impl_name}"
        rm -Rf $fpga_tmp
        exit 1
    fi

    suffix_name=${impl}_"lbp=${lbp_entries}_lhr=${lhr_entries}"

    cp -Rf $fpga_tmp/corev_apu/fpga/work-fpga/ariane_xilinx.bit corev_apu/fpga/bitstreams/ariane_xilinx_${suffix_name}.bit
    cp -Rf $fpga_tmp/corev_apu/fpga/ariane.xpr corev_apu/fpga/xilinx_projects/ariane_${suffix_name}.xpr
    cp -Rf $fpga_tmp/corev_apu/fpga/vivado.log corev_apu/fpga/logs/vivado_${suffix_name}.log
    rm -Rf $fpga_tmp
}

generate_bitstream_tournament() {
    impl=$1
    impl_name=$2
    mbp_entries=$(echo "$3" | tr "-" " " | cut -d " " -f1,1)
    gbp_entries=$(echo "$3" | tr "-" " " | cut -d " " -f2,2)
    lbp_entries=$(echo "$3" | tr "-" " " | cut -d " " -f3,3)
    lhr_entries=$(echo "$3" | tr "-" " " | cut -d " " -f4,4)

    fpga_tmp=$(mktemp -d)

    cp -Rf common $fpga_tmp
    cp -Rf core $fpga_tmp
    cp -Rf corev_apu $fpga_tmp
    cp -Rf vendor $fpga_tmp

    make -C $fpga_tmp/corev_apu/fpga bit_${impl_name} BOARD=$BOARD \
                               XILINX_PART=$XILINX_PART \
                               XILINX_BOARD=$XILINX_BOARD \
                               CLK_PERIOD_NS=$CLK_PERIOD_NS \
                               BRANCH_PRED_IMPL=${impl} \
                               MBP_ENTRIES=${mbp_entries} \
                               GBP_ENTRIES=${gbp_entries} \
                               LBP_ENTRIES=${lbp_entries} \
                               LHR_ENTRIES=${lhr_entries}

    if [ $? -ne 0 ]; then
        echo "Error: MAKE command failed for BRANCH_PRED_IMPL=${impl_name}"
        rm -Rf $fpga_tmp
        exit 1
    fi

    suffix_name=${impl}_"mbp=${mbp_entries}_gbp=${gbp_entries}_lbp=${lbp_entries}_lhr=${lhr_entries}"

    cp -Rf $fpga_tmp/corev_apu/fpga/work-fpga/ariane_xilinx.bit corev_apu/fpga/bitstreams/ariane_xilinx_${suffix_name}.bit
    cp -Rf $fpga_tmp/corev_apu/fpga/ariane.xpr corev_apu/fpga/xilinx_projects/ariane_${suffix_name}.xpr
    cp -Rf $fpga_tmp/corev_apu/fpga/vivado.log corev_apu/fpga/logs/vivado_${suffix_name}.log
    rm -Rf $fpga_tmp
}

export -f generate_bitstream_bht
export -f generate_bitstream_gbp
export -f generate_bitstream_lbp
export -f generate_bitstream_tournament

make -C corev_apu/fpga ips_rule BOARD=$BOARD \
                  XILINX_PART=$XILINX_PART \
                  XILINX_BOARD=$XILINX_BOARD \
                  CLK_PERIOD_NS=$CLK_PERIOD_NS

if [ ! -d  corev_apu/fpga/bitstreams ]; then
    mkdir corev_apu/fpga/bitstreams
fi

if [ ! -d  corev_apu/fpga/xilinx_projects ]; then
    mkdir corev_apu/fpga/xilinx_projects
fi

if [ ! -d  corev_apu/fpga/logs ]; then
    mkdir corev_apu/fpga/logs
fi

temp=$(mktemp)
for (( i = 0; i < ${#BRANCH_PRED_IMPL_NAMES[@]}; i++ )); do
    impl_name=${BRANCH_PRED_IMPL_NAMES[$i]}
    configs=$(eval echo \${${ALL_CONFIGS[$i]}[@]})
    for config in ${configs}; do
      echo "${i} ${impl_name} ${config}" >> ${temp}
    done
done

cat "$temp" | xargs -P2 -I{} bash -c '
  tuple="{}"
  impl=$(echo ${tuple} | tr -s " " | cut -d " " -f1,1)
  impl_name=$(echo ${tuple} | tr -s " " | cut -d " " -f2,2)
  config=$(echo ${tuple} | tr -s " " | cut -d " " -f3,3)
  generate_bitstream_${impl_name} ${impl} ${impl_name} ${config}
'



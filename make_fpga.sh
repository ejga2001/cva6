#!/bin/bash

BRANCH_PRED_IMPL_NAMES=("bht" "gbp" "lbp" "tournament")
BHT_CONFIGS=("8192:3" "16384:3" "32768:3" "65536:3" "131072:3")
GLOBAL_CONFIGS=("8192:3" "16384:3" "32768:3" "65536:3" "131072:3")
LOCAL_CONFIGS=("4096:2048:1" "4096:4096:3" "8192:8192:2" "16384:16384:1" "65536:16384:2")
TOURNAMENT_CONFIGS=("1024:2048:4096:1024" "1024:4096:8192:2048" \
                    "2048:16384:16384:2048" "8192:8192:32768:8192" "8192:16384:65536:16384")
ALL_CONFIGS=("BHT_CONFIGS" "GLOBAL_CONFIGS" "LOCAL_CONFIGS" "TOURNAMENT_CONFIGS")

export BOARD=$1
export XILINX_PART=$2
export XILINX_BOARD=$3
export CLK_PERIOD_NS=$4

generate_bitstream_bht() {
    impl=$1
    impl_name=$2
    bht_entries=$(echo $3 | cut -d ":" -f1,1)
    ctr_bits=$(echo $3 | cut -d ":" -f2,2)
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
                               BHT_ENTRIES=${bht_entries} \
                               BHT_CTR_BITS=${ctr_bits}

    if [ $? -ne 0 ]; then
        echo "Error: MAKE command failed for BRANCH_PRED_IMPL=${impl_name}"
        rm -Rf $fpga_tmp
        exit 1
    fi

    suffix_name=${impl}_"bht=${bht_entries}_ctrbits=${ctr_bits}"

    cp -Rf $fpga_tmp/corev_apu/fpga/work-fpga/ariane_xilinx.bit corev_apu/fpga/bitstreams/ariane_xilinx_${suffix_name}.bit
    cp -Rf $fpga_tmp/corev_apu/fpga/reports/* corev_apu/fpga/reports
    cp -Rf $fpga_tmp/corev_apu/fpga/ariane.xpr corev_apu/fpga/xilinx_projects/ariane_${suffix_name}.xpr
    cp -Rf $fpga_tmp/corev_apu/fpga/vivado.log corev_apu/fpga/logs/vivado_${suffix_name}.log
    rm -Rf $fpga_tmp
}

generate_bitstream_gbp() {
    impl=$1
    impl_name=$2
    gbp_entries=$(echo $3 | cut -d ":" -f1,1)
    ctr_bits=$(echo $3 | cut -d ":" -f2,2)

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
                               GBP_ENTRIES=${gbp_entries} \
                               GLOBAL_CTR_BITS=${ctr_bits}

    if [ $? -ne 0 ]; then
        echo "Error: MAKE command failed for BRANCH_PRED_IMPL=${impl_name}"
        rm -Rf $fpga_tmp
        exit 1
    fi

    suffix_name=${impl}_"gbp=${gbp_entries}_ctrbits=${ctr_bits}"

    cp -Rf $fpga_tmp/corev_apu/fpga/work-fpga/ariane_xilinx.bit corev_apu/fpga/bitstreams/ariane_xilinx_${suffix_name}.bit
    cp -Rf $fpga_tmp/corev_apu/fpga/reports/* corev_apu/fpga/reports
    cp -Rf $fpga_tmp/corev_apu/fpga/ariane.xpr corev_apu/fpga/xilinx_projects/ariane_${suffix_name}.xpr
    cp -Rf $fpga_tmp/corev_apu/fpga/vivado.log corev_apu/fpga/logs/vivado_${suffix_name}.log
    rm -Rf $fpga_tmp
}

generate_bitstream_lbp() {
    impl=$1
    impl_name=$2
    lbp_entries=$(echo "$3" | cut -d ":" -f1,1)
    lhr_entries=$(echo "$3" | cut -d ":" -f2,2)
    ctr_bits=$(echo "$3"| cut -d ":" -f3,3)

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
                               LHR_ENTRIES=${lhr_entries} \
                               LOCAL_CTR_BITS=${ctr_bits}

    if [ $? -ne 0 ]; then
        echo "Error: MAKE command failed for BRANCH_PRED_IMPL=${impl_name}"
        rm -Rf $fpga_tmp
        exit 1
    fi

    suffix_name=${impl}_"lbp=${lbp_entries}_lhr=${lhr_entries}_ctrbits=${ctr_bits}"

    cp -Rf $fpga_tmp/corev_apu/fpga/work-fpga/ariane_xilinx.bit corev_apu/fpga/bitstreams/ariane_xilinx_${suffix_name}.bit
    cp -Rf $fpga_tmp/corev_apu/fpga/reports/* corev_apu/fpga/reports
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
                               LHR_ENTRIES=${lhr_entries} \
                               CHOICE_CTR_BITS=2 \
                               GLOBAL_CTR_BITS=2 \
                               LOCAL_CTR_BITS=2

    if [ $? -ne 0 ]; then
        echo "Error: MAKE command failed for BRANCH_PRED_IMPL=${impl_name}"
        rm -Rf $fpga_tmp
        exit 1
    fi

    suffix_name=${impl}_"mbp=${mbp_entries}_gbp=${gbp_entries}_lbp=${lbp_entries}_lhr=${lhr_entries}"

    cp -Rf $fpga_tmp/corev_apu/fpga/work-fpga/ariane_xilinx.bit corev_apu/fpga/bitstreams/ariane_xilinx_${suffix_name}.bit
    cp -Rf $fpga_tmp/corev_apu/fpga/reports/* corev_apu/fpga/reports
    cp -Rf $fpga_tmp/corev_apu/fpga/ariane.xpr corev_apu/fpga/xilinx_projects/ariane_${suffix_name}.xpr
    cp -Rf $fpga_tmp/corev_apu/fpga/vivado.log corev_apu/fpga/logs/vivado_${suffix_name}.log
    rm -Rf $fpga_tmp
}

export -f generate_bitstream_bht
export -f generate_bitstream_gbp
export -f generate_bitstream_lbp
export -f generate_bitstream_tournament

source "/home/enriquejga/Xilinx/Vivado/2018.2/settings64.sh"

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

if [ ! -d  corev_apu/fpga/reports ]; then
    mkdir corev_apu/fpga/reports
fi

temp=$(mktemp)
for (( i = 0; i < ${#BRANCH_PRED_IMPL_NAMES[@]}; i++ )); do
    impl_name=${BRANCH_PRED_IMPL_NAMES[$i]}
    configs=$(eval echo \${${ALL_CONFIGS[$i]}[@]})
    for config in ${configs}; do
      echo "${i} ${impl_name} ${config}" >> ${temp}
    done
done

cat "$temp" | xargs -P5 -I{} bash -c '
  tuple="{}"
  impl=$(echo ${tuple} | tr -s " " | cut -d " " -f1,1)
  impl_name=$(echo ${tuple} | tr -s " " | cut -d " " -f2,2)
  config=$(echo ${tuple} | tr -s " " | cut -d " " -f3,3)
  taskset -c ${impl} generate_bitstream_${impl_name} ${impl} ${impl_name} ${config}
'

rm -f "$temp"
echo "DONE"
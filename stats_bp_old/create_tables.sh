#!/bin/bash

get_impl () {
  local name_dir=$1

  impl_num=$(echo $name_dir | cut -d "_" -f3,3)
  impl=""
  kbits=""
  params=$(echo $name_dir | cut -d "_" -f4-)
  case ${impl_num} in
  0)
    impl="Bimodal"
    ;;
  1)
    impl="Gshare"
    ;;
  2)
    impl="Local"
    ;;
  3)
    impl="Tournament"
    ;;
  4)
    impl="TAGE"
    ;;
  esac
  case ${params} in
  "bht=16384"|"gbp=16384"|"lbp=4096_lhr=2048_ctrbits=2"|"mbp=2048_gbp=4096_lbp=4096_lhr=1024"|"bimodal=8192_power=1_ubitperiod=2048")
    kbits="32"
    ;;
  "bht=32768"|"gbp=32768"|"lbp=4096_lhr=4096_ctrbits=4"|"mbp=8192_gbp=8192_lbp=4096_lhr=2048"|"bimodal=16384_power=2_ubitperiod=2048")
    kbits="64"
    ;;
  "bht=65536"|"gbp=65536"|"lbp=8192_lhr=8192_ctrbits=3"|"mbp=4096_gbp=16384_lbp=16384_lhr=4096"|"bimodal=32768_power=3_ubitperiod=2048")
    kbits="128"
    ;;
  "bht=131072"|"gbp=131072"|"lbp=16384_lhr=16384_ctrbits=2"|"mbp=16384_gbp=16384_lbp=65536_lhr=4096"|"bimodal=65536_power=4_ubitperiod=2048")
    kbits="256"
    ;;
  "bht=262144"|"gbp=262144"|"lbp=65536_lhr=16384_ctrbits=3"|"mbp=32768_gbp=32768_lbp=65536_lhr=16384"|"bimodal=131072_power=5_ubitperiod=2048")
    kbits="512"
    ;;
  esac
  echo "$impl ($kbits Kbits)"
}

STATS_DIR="/home/enrique/CLionProjects/cva6/stats_bp"

STATS_DIRS=$(find ${STATS_DIR}/* -type d)

for stat_dir in ${STATS_DIRS} ; do
  STATS_BENCHMARKS=$(find ${stat_dir}/* -type f)
  echo "Implementation: $(get_impl "$(basename $stat_dir)")"
  for stat in ${STATS_BENCHMARKS} ; do
      echo "Benchmark: $(basename $stat)" | cut -d "_" -f2,2
      bm_ratio=""
      ipc=""
      while IF= read -r line; do
        if [[ $line =~ "of all branches" ]]; then
          bm_ratio=$(echo $line | tr -s " " | cut -d " " -f4,4 | tr "%" " ")
          echo "Ratio of branch misses: ${bm_ratio}%"
        elif [[ $line =~ "insn per cycle" ]]; then
          ipc=$(echo $line | tr -s " " | cut -d " " -f4,4)
          echo "IPC: ${ipc}"
        fi
      done < "$stat"
      echo
  done
  echo "----------------------------"
done
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
  "bht=8192"|"gbp=8192"|"lbp=4096_lhr=2048_ctrbits=1"|"mbp=1024_gbp=2048_lbp=4096_lhr=1024"|"bimodal=8192_power=1_ubitperiod=2048")
    kbits="32"
    ;;
  "bht=16384"|"gbp=16384"|"lbp=4096_lhr=4096_ctrbits=3"|"mbp=1024_gbp=4096_lbp=8192_lhr=2048"|"bimodal=16384_power=2_ubitperiod=2048")
    kbits="64"
    ;;
  "bht=32768"|"gbp=32768"|"lbp=8192_lhr=8192_ctrbits=2"|"mbp=2048_gbp=16384_lbp=16384_lhr=2048"|"bimodal=32768_power=3_ubitperiod=2048")
    kbits="128"
    ;;
  "bht=65536"|"gbp=65536"|"lbp=16384_lhr=16384_ctrbits=1"|"mbp=8192_gbp=8192_lbp=32768_lhr=8192"|"bimodal=65536_power=4_ubitperiod=2048")
    kbits="256"
    ;;
  "bht=131072"|"gbp=131072"|"lbp=65536_lhr=16384_ctrbits=2"|"mbp=8192_gbp=16384_lbp=65536_lhr=16384"|"bimodal=131072_power=5_ubitperiod=2048")
    kbits="512"
    ;;
  esac
  echo "$impl ($kbits Kbits)"
}

STATS_DIR="/home/enrique/CLionProjects/cva6/stats_bp_gem5"

STATS_DIRS=$(find ${STATS_DIR}/* -type d -name "ariane*")

for stats_dir in ${STATS_DIRS} ; do
  STATS_BENCHMARKS_DIR=$(find ${stats_dir}/* -type d)
  echo "Implementation: $(get_impl "$(basename $stats_dir)")"
  for stat_dir in ${STATS_BENCHMARKS_DIR} ; do
      stat="${stat_dir}/stats.txt"
      echo "Benchmark: $(basename $stat_dir)" | cut -d "_" -f2,2
      branches=""
      branch_misses=""
      bm_ratio=""
      ipc=""
      while IF= read -r line; do
        if [[ $line =~ branchPred.committed_0::total ]]; then
          branches=$(echo $line | tr -s " " | cut -d " " -f2,2 | tr "%" " ")
          #echo "Number of branches: ${branches}"
        elif [[ $line =~ branchPred.mispredicted_0::total ]]; then
          branch_misses=$(echo $line | tr -s " " | cut -d " " -f2,2 | tr "%" " ")
          #echo "Number of branch misses: ${branch_misses}"
        elif [[ $line =~ core\.ipc ]]; then
          ipc=$(echo $line | tr -s " " | cut -d " " -f2,2)
          echo "IPC: ${ipc}"
        fi
        if [ ! -z "${branches}" ] && [ ! -z "${branch_misses}" ] && [ -z "${bm_ratio}" ]; then
           bm_ratio=$(echo "scale=2; (${branch_misses} * 100) / ${branches}" | bc -l)
           if [[ $bm_ratio == .* ]]; then
               bm_ratio="0${bm_ratio}"
           fi
          echo "Ratio of branch misses: ${bm_ratio}%"
        fi
      done < "$stat"
      echo
  done
  echo "----------------------------"
done
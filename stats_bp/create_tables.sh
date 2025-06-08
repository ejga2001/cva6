#!/bin/bash

get_impl () {
  local name_dir=$1

  impl_num=$(echo $name_dir | cut -d "_" -f3,3)
  impl=""
  params=$(echo $name_dir | cut -d "_" -f4-)
  case ${impl_num} in
  0)
    impl="bht"
    ;;
  1)
    impl="gbp"
    ;;
  2)
    impl="lbp"
    ;;
  3)
    impl="tournament"
    ;;
  esac
  echo "$impl ($params)"
}

STATS_DIR="/home/enrique/CLionProjects/cva6/stats_bp"

STATS_DIRS=$(find ${STATS_DIR}/* -type d)

for stat_dir in ${STATS_DIRS} ; do
  STATS_BENCHMARKS=$(find ${stat_dir}/* -type f)
  echo "Implementation: $(get_impl "$(basename $stat_dir)")"
  for stat in ${STATS_BENCHMARKS} ; do
      echo "Benchmark: $(basename $stat)" | cut -d "_" -f2,2
      cycles=""
      instructions=""
      branches=""
      branch_misses=""
      printed_bm=0
      ipc=""
      printed_ipc=0
      while IF= read -r line; do
        if [[ $line =~ "branches" ]]; then
          if [[ $line =~ "branch-misses" ]]; then
            branch_misses=$(echo $line | tr -s " " | cut -d " " -f1,1)
            echo "Branch misses: $branch_misses"
          else
            branches=$(echo $line | tr -s " " | cut -d " " -f1,1)
            echo "Branches: $branches"
          fi
        elif [[ $line =~ "cycles" ]]; then
          cycles=$(echo $line | tr -s " " | cut -d " " -f1,1)
        elif [[ $line =~ "instruction" ]]; then
          instructions=$(echo $line | tr -s " " | cut -d " " -f1,1)
        fi
        if [ -n "$cycles" ] && [ -n "$instructions" ] && [ $printed_ipc == 0  ]; then
            ipc=$(echo "$instructions / $cycles" | bc -l | sed 's/^\./0./')
            ipc_rounded=$(LC_NUMERIC=C printf "%.2f" "$ipc")
            echo "IPC: $ipc_rounded"
            printed_ipc=1
        fi
        if [ -n "$branches" ] && [ -n "$branch_misses" ] && [ $printed_bm == 0 ]; then
          bm_ratio=$(echo "$branch_misses / $branches * 100" | bc -l | sed 's/^\./0./')
          bm_ratio_rounded=$(LC_NUMERIC=C printf "%.2f" "$bm_ratio")
          echo "Ratio of branch misses: $bm_ratio_rounded %"
          printed_bm=1
        fi
      done < "$stat"
  done
  echo "----------------------------"
done
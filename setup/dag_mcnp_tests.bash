#!/bin/bash

# Get cross section data
function get_xs_data() {
  mkdir -p $DATAPATH
  cd $DATAPATH
  get_tar $xs_data_tar squid
  tar -xzvf $xs_data_tar --strip-components=1
  rm -f $xs_data_tar
}

# Run the DAG-MCNP tests
function dag_mcnp_tests() {
  cd $copy_dir
  git clone https://github.com/ljacobson64/DAGMC-tests
  cd DAGMC-tests
  bash get_files.bash

  # - Run longer tests in MPI mode
  # - Order for serial runs is from longest to shortest
  # - Runs with PTRAC must be run in serial
  # - Runs with dependencies on other runs must come after those runs

  cd DAGMC
  mpi_runs="13 9 15 14"
  python run_tests.py $mpi_runs -s -r -j $jobs --mpi
  ser_runs="5 6 1 8 7 11 10 2 3 4 12"
  python run_tests.py $ser_runs -s -r -j $jobs

  cd ../Meshally
  python run_tests.py -s -r -j $jobs --mpi

  cd ../Regression
  mpi_runs="35 37"
  python run_tests.py $mpi_runs -s -r -j $jobs --mpi
  ser_runs="36 2 41 31 42 4 39 98 99 6 90 93 33 95 30 1 7 64 12 3 68 20 32 21 23 10 28 19 9 94 47 61 63 65 66 67 86 62"
  python run_tests.py $ser_runs -s -r -j $jobs
  ser_runs="22 8 29 34 26 27"  # dependencies
  python run_tests.py $ser_runs -s -r -j $jobs

  cd ../VALIDATION_CRITICALITY
  python run_tests.py -s -r -j $jobs --mpi

  cd ../VALIDATION_SHIELDING
  python run_tests.py -s -r -j $jobs --mpi

  cd ../VERIFICATION_KEFF
  ser_runs="10 23 9"  # ptrac
  python run_tests.py $mpi_runs -s -r -j $jobs --mpi
  mpi_runs=`seq 75`
  for s_run in $ser_runs; do mpi_runs=${mpi_runs/$s_run}; done
  python run_tests.py $ser_runs -s -r -j $jobs

  cd $copy_dir
}

# Pack results tarball
function pack_results() {
  cd $copy_dir/DAGMC-tests
  tar -czvf $results_tar */Results
  mv $results_tar $copy_dir
  cd $copy_dir
}

# Delete unneeded stuff
function cleanup() {
  rm -rf $base_dir/*
  cd $copy_dir
  ls | grep -v $results_tar | xargs rm -rf
}

set -e
export args="$@"
export args=" "$args" "

# Common functions
source ./common.bash

# Parallel jobs
export jobs=12

# Username where tarballs are found (/squid/$username)
export username=$1

# Tarball names
export compile_tar=compile.tar.gz
export dagmc_tar=dagmc.tar.gz
export xs_data_tar=mcnp_data.tar.gz
export results_tar=results.tar.gz

# Directory names
export copy_dir=$PWD
export base_dir=$HOME
export compile_dir=$base_dir/compile
export dagmc_dir=$base_dir/dagmc
export DATAPATH=$base_dir/mcnp_data

# Get compilers, DAGMC, and xs_data
get_compile
get_dagmc
get_xs_data

# Run the DAG-MCNP5 tests
dag_mcnp_tests

# Pack results
pack_results

# Delete unneeded stuff
cleanup
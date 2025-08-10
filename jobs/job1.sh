#!/bin/bash
#SBATCH --job-name=s_diag_con_graphs_1to11
#SBATCH --account=def-mbetti
#SBATCH --cpus-per-task=40
#SBATCH --time=30:00
#SBATCH --mem=4G

MAIN="/home/pusheen/scratch/small-graph-s-bandwidths/src/main.sh"
SRC="/home/pusheen/scratch/small-graph-s-bandwidths/data/input/laplacian_integral_con_graphs_1to11.txt"
DST="/home/pusheen/scratch/small-graph-s-bandwidths/data/small_graph_s_bandwidths.db"
TBL_NAME="con_graphs_1to11"

NTHREADS=32

module load StdEnv/2023
module load julia/1.11.3
module load python/3.13.2
source ~/.venv_313/bin/activate

export JULIA_NUM_THREADS="$NTHREADS"
export OPENBLAS_NUM_THREADS=1

bash "$MAIN" "$SRC" "$DST" "$TBL_NAME"

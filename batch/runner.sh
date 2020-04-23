#!/bin/bash

set -x
set -e

# Expected environment variables from AWS Batch env
# S3_MODEL_DATA_PATH location in S3 with the code, data, and dvc pipeline to run
# DVC_TARGET the name of the dvc file in the model that should be reproduced locally.
# DVC_OUTPUTS the names of the directories with outputs to save in S3, separated by a space
# S3_RESULTS_PATH location in S3 to store the results

# setup the python environment
HOME=/home/app
PYENV_ROOT=$HOME/.pyenv
PYTHON_VERSION=3.7.6
PYTHON_VENV_DIR=$HOME/python_venv
PATH=$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH
. $PYTHON_VENV_DIR/bin/activate

# set optimized S3 configuration
aws configure set default.s3.max_concurrent_requests 100
aws configure set default.s3.max_queue_size 100
aws configure set default.s3.multipart_threshold 8MB
aws configure set default.s3.multipart_chunksize 8MB

# Copy the complete model + data package from S3 and
# install the local R packages
aws s3 cp $S3_MODEL_DATA_PATH model_data.tar.gz
mkdir model_data
tar -xvzf model_data.tar.gz -C model_data
cd model_data

# Track our offset for writing unique output files
export AWS_BATCH_SIM_OFFSET=$((${AWS_BATCH_JOB_ARRAY_INDEX:-0} * ${SIMS_PER_JOB:-0}))

# Initialize dvc and run the pipeline to re-create the
# dvc target
dvc init --no-scm
dvc repro $DVC_TARGET

DVC_OUTPUTS_ARRAY=($DVC_OUTPUTS)
for output in "${DVC_OUTPUTS_ARRAY[@]}"
do
	if [ -d "$output" ]; then     
        	aws s3 cp --quiet --recursive $output $S3_RESULTS_PATH/$output/
	fi
done

echo "Done"

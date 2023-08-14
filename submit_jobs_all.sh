#!/bin/bash
# Written by Rohith Saradhy

settings_file=settings/settings.json

# echo flashgg $camp $cmdLine

#########################################
############### FUNCTIONS ###############
#########################################
#
spin="-"
function moving_dots()
{
    if [ -z "$spin" ]; then
        spin="-"   
    elif [ $spin == "-" ]; then
        spin="\\"
    elif [ $spin == "\\" ]; then
        spin="|"   
    elif [ $spin == "|" ]; then
        spin="/"   
    elif [ $spin == "/" ]; then
        spin="-" 

    fi
}


function get_json_val()
{
    echo $(cat $settings_file | jq -r $1)
}

function get_json_val_withoutr()
{
    echo $(cat $settings_file | jq  $1)
}


function fggRun()
{
    json=$1
    outdir=$2
    eos_dir=$3
    batch_size=$4
    queue=$5
    dumper=$6
    nEvents=$7
    additional_cmd=$8
    nohup_output_file=$9.txt
    
    nohup fggRunJobs.py --load $json \
              -d $outdir \
              --stage-to $eos_dir \
              -n $batch_size \
              -q $queue \
              --no-copy-proxy \
              --make-light-tarball \
              -x cmsRun $dumper maxEvents=$nEvents copyInputMicroAOD=True $additional_cmd > $nohup_output_file &
}
################################################
############### END OF FUNCTIONS ###############
################################################



folder_name=$(get_json_val ".common.folder_name")
dumper=$(get_json_val ".common.dumper")
nEvents=$(get_json_val ".common.nEvents")
additionalSettings=$(get_json_val ".common.additionalSettings")
eosDir=$(get_json_val ".common.eosDir")
afsDir=$(get_json_val ".common.afsDir")
folder_comment=$(get_json_val ".common.folder_comment")



era_list=(UL18 UL17 UL16post UL16pre)
procTypeToDo=(sig data bkg)

# era_list=(UL17)
# procTypeToDo=(data)

for era in ${era_list[@]}; do
    # procTypeToDo=(sig)
    echo "==============================================================="
    echo 'ERA:   '$era
    echo 'procs: '${procTypeToDo[@]}
    echo "==============================================================="
    #copy this file to the folder for reference...
    echo "Copying settings file & submit_jobs"
    mkdir -p "$eosDir/$folder_name/$era" #remove echo
    cp submit_jobs_all.sh $settings_file $eosDir/$folder_name/$era
    echo $(date)  "::" $era "["${procTypeToDo[@]}"]"  "-->" $folder_comment >> $eosDir/$folder_name/$era/status.log 
    echo $(date)  ":: Submitting from $(hostname) "  >> $eosDir/$folder_name/$era/status.log 
    echo "Writing Log to : $eosDir/$folder_name/$era/status.log"
    echo "==============================================================="


    for json_name in $(get_json_val ".$era.json_list|keys[]"); do
        json_folder=$(get_json_val ".$era.json_folder")
        proctype=$(get_json_val ".$era.json_list.$json_name")
        json_file=$json_folder/$json_name.json
        job_num=$(get_json_val ".$era.$proctype.jobNum")
        queue=$(get_json_val ".$era.$proctype.queue")
        output_folderName=$(get_json_val ".$era.$proctype.output_folderName")

        writeFolder=$eosDir/$folder_name/$era/raw/$output_folderName
        localFolder=$afsDir/$folder_name/$era/
        
        # echo $json_folder/$json_name $proctype  
        #if proctype in procTypeToDo, execute
        if printf '%s\0' "${procTypeToDo[@]}" | grep -qwz $proctype
        then
            
            #make the folder...
            mkdir -p $writeFolder #remove echo
            mkdir -p $localFolder #remove echo
            echo $(date)  ":: Submitting ($proctype) " $json_file "" >> $eosDir/$folder_name/$era/status.log 
            echo "Submitting jobs for " $json_file
            echo "Look at this folder: " $localFolder

            # some initial variables to keep track of jobs and directory
            currentDir=$PWD #Saving the root dir
            last_condorID=$(condor_q | awk '$1 ~ "rsaradhy" {printf "%s\n",$3}' | tail -n 1)
            echo "Last Condor Record:" $last_condorID
            echo "==============================================================="
            cd $localFolder #Going to the localFolder
            nohup_file="nohup_output_$json_name"
            localFolder=$json_name #localFolder
            mkdir -p $localFolder
            if [ -f "$localFolder/config.json" ]; then
                echo ">>> You are trying to write to a folder which already has something"
                echo ">>> Please change folder_name in settings.json or delete this:"
                echo "    $afsDir/$folder_name/$era/$localFolder"
                echo ">>> I am continuing to the next item if it exists"
                echo "==============================================================="
                continue
            fi
            echo "==============================================================="
            echo "Submitting Jobs using fggRun" 
            fggRun $currentDir/$json_file $localFolder $writeFolder $job_num $queue $dumper $nEvents "$additionalSettings" $nohup_file

            # check if the condor gets submitted
            totalJobsToSubmit=$(cat $currentDir/$json_file | jq  ".processes[]|keys[]" | wc -l )
            echo "Jobs waiting to be submitted: $totalJobsToSubmit" 

            # first check if all the sh files are created
            sleepTimer=1
            numOfshFiles=0
            while [ $numOfshFiles -lt $totalJobsToSubmit ];do
                if [ -f "$localFolder/runJobs0.sh" ]; then
                    numOfshFiles=$(ls -l $localFolder/runJobs*.sh | wc -l)
                else
                    numOfshFiles=0
                fi
                for variable in {1..5}; do #this is for telling the user things are working!!!!
                    echo -ne "Checking for runJobs: $numOfshFiles / $totalJobsToSubmit Found  $spin \r" 
                    moving_dots
                    sleep $sleepTimer;
                done
            done
            echo "Checking for runJobs: $numOfshFiles / $totalJobsToSubmit Found       " 
            echo "All $numOfshFiles / $totalJobsToSubmit Found!!! Proceeding..."
            echo "==============================================================="
            
            #second check if all the jobs are submitted
            prev_job=$last_condorID
            currentJobnum=0
            spin="-"
            while [ $currentJobnum -lt $totalJobsToSubmit ]; do
                for variable in {1..20}; do #this is for telling the user things are working!!!!
                    echo -ne "Waiting for Jobs: $currentJobnum out of $totalJobsToSubmit  Submitted $spin \r"  
                    moving_dots
                    sleep 1
                done
                currentJobnum="$(condor_q | awk '$1 ~ "rsaradhy" {printf "%s\n",$3}' | awk -v prevJob=$prev_job '$1 > prevJob {print $1}' | wc -l )"
            done
            echo "==============================================================="
            echo "Killing all submission scripts and Moving to the next one"
            killall python
            killall nohup 
            echo "==============================================================="

            cd $currentDir
        fi
    done
done

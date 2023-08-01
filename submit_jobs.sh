#!/bin/bash

settings_file=settings/settings.json

# echo flashgg $camp $cmdLine

#########################################
############### FUNCTIONS ###############
#########################################
#

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





era="UL18"
# procTypeToDo=(bkg data sig)
procTypeToDo=(sig)
echo '$$$$$$$$$$$$$$$$$$$$$$'
echo 'ERA:   '$era
echo 'procs: '${procTypeToDo[@]}
echo '$$$$$$$$$$$$$$$$$$$$$$'


#copy this file to the folder for reference...
echo "Copying settings file & submit_jobs"
mkdir -p "$eosDir/$folder_name/$era" #remove echo
cp submit_jobs.sh $settings_file $eosDir/$folder_name/$era
echo $(date)  "::" $era "["${procTypeToDo[@]}"]"  "-->" $folder_comment >> $eosDir/$folder_name/$era/status.log 
echo $(date)  ":: Submitting from $(hostname) "  >> $eosDir/$folder_name/$era/status.log 
echo '$$$$$$$$$$$$$$$$$$$$$$'


for json_name in $(get_json_val ".$era.json_list|keys[]"); do
    json_folder=$(get_json_val ".$era.json_folder")
    proctype=$(get_json_val ".$era.json_list.$json_name")
    json_file=$json_folder/$json_name.json
    job_num=$(get_json_val ".$era.$proctype.jobNum")
    queue=$(get_json_val ".$era.$proctype.queue")
    output_folderName=$(get_json_val ".$era.$proctype.output_folderName")

    writeFolder=$eosDir/$folder_name/$era/raw/$output_folderName
    localFolder=$afsDir/$folder_name/$era/$json_name
    
    #if proctype in procTypeToDo, execute
    if printf '%s\0' "${procTypeToDo[@]}" | grep -qwz $proctype
    then
        
        #make the folder...
        mkdir -p $writeFolder #remove echo
        mkdir -p $localFolder #remove echo
        # echo  $json_file : $proctype
        echo $(date)  ":: Submitting ($proctype) " $json_file "" >> $eosDir/$folder_name/$era/status.log 
        echo "Submitting jobs for " $json_file

        nohup_file=$afsDir/$folder_name/$era/"nohup_output_$json_name"
        fggRun $json_file $localFolder $writeFolder $job_num $queue $dumper $nEvents "$additionalSettings" $nohup_file

    # else
    #     echo $json_file : $proctype Skipped
    fi
done







# fggRun 1 2 3 4 5 6 7 8 
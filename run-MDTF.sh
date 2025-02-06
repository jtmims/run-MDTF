#!/bin/bash -f
#SBATCH --job-name=run-MDTF.sh
#SBATCH --time=4:00:00
#set -x

# dir references
run_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
#mdtf_dir=/home/oar.gfdl.mdtf/mdtf/MDTF-diagnostics
mdtf_dir=/home/Jacob.Mims/mdtf/MDTF-diagnostics
catbuilddir=/home/Jacob.Mims/CatalogBuilder/

echo $run_dir

#TEST: /archive/jpk/fre/FMS2024.02_OM5_20240819/CM4.5v01_om5b06_piC_noBLING_xrefine_test4/gfdl.ncrc5-intel23-prod-openmp/pp/

#TEST 2: /archive/djp/am5/am5f7b12r1/c96L65_am5f7b12r1_amip/gfdl.ncrc5-intel23-classic-prod-openmp/pp/

usage() {
   echo "USAGE: run-mdtf.sh /path/to/pp/dir/pp out_dir/mdtf startyr endyr"   
}

# handle arguments
if [[ $# -ne 4 ]] ; then
   usage
   exit 0
fi
if [ -d $1 ]; then
   ppdir=$1
else
   echo "ERROR: $1 is not a directory"
   usage
   exit
fi
if [ -d $2 ]; then
   outdir=$2
else
   mkdir -p $2
   outdir=$2
fi
startyr=$3
endyr=$4

# check to see if catalog exists
#  ^..^
# /o  o\   
# oo--oo~~~
echo "looking for catalog in $ppdir"
cat=$(grep -s -H "esmcat_version" $ppdir/*.json  | cut -d: -f1)
if [[ "$cat" == "" ]]; then
   activate=/home/oar.gfdl.mdtf/miniconda3/bin/activate
   env=/nbhome/Aparna.Radhakrishnan/conda/envs/catalogbuilder
   source $activate $env 
   python $run_dir/scripts/cat_builder.py $catbuilddir $ppdir $outdir/catalog
   cat=$outdir/catalog.json
   echo "new catalog generated: $cat"
else
   echo "found catalog: $cat"
fi

# search catalog for pod requirements
activate=/home/oar.gfdl.mdtf/miniconda3/bin/activate
env=/home/oar.gfdl.mdtf/miniconda3/envs/_MDTF_base
source $activate $env
python $run_dir/scripts/req_var_search.py $cat $run_dir/data/

# make list of pre-canned config files to use
mapfile -t runnable_pods < $run_dir/data/runnable_pods.txt
echo $runnable_pods

declare -a files=(
[0]="atmos_cmip_config.jsonc"
[1]="ice_config.jsonc"
)
if [ $startyr -le 2003 ] && [ $endyr -ge 2014 ]; then
   files=("${files[@]}"  "atmos_cmip_ffb.jsonc")
fi

# edit config files
for f in "${files[@]}" ; do
   cp $run_dir/config/$f $outdir/$f
   config='"DATA_CATALOG": "",'
   config_edit='"DATA_CATALOG": "'"${cat}"'",'
   sed -i "s|$config|$config_edit|ig" $outdir/$f
   config='"WORK_DIR": "",'
   config_edit='"WORK_DIR": "'"${outdir}"'",'
   sed -i "s|$config|$config_edit|ig" $outdir/$f
   # handle atmos_cmip PODs
   config='"startdate": "",'
   config_edit='"startdate": "'"${startyr}"'",'
   sed -i "s|$config|$config_edit|ig" $outdir/$f
   config='"enddate": ""'
   config_edit='"enddate": "'"${endyr}"'"'
   sed -i "s|$config|$config_edit|ig" $outdir/$f
   echo "edited file $f"
done

# launch the mdtf with the config files
for f in "${files[@]}" ; do
   if [ -f $outdir/$f ]; then
      echo "launching MDTF with $f"
      "$mdtf_dir"/mdtf -f $outdir/$f
   fi
done

# consolidate into a single output folder
mapfile -t pods < $run_dir/data/pods.txt
for od in "$outdir"/"MDTF_output.v"*; do
   for pd in $od/*; do
      if [ -d $pd ]; then
         pod=$(basename "$pd")
         for name in ${pods[@]}; do
            if [[ "$pod" == "$name" ]]; then
              mv $pd "$outdir"/"MDTF_output"
            fi
         done
      fi
   done
   if [ -f "$od"/"index.html" ]; then
      cat "$od"/"index.html" >> "$outdir"/"MDTF_output"/"index.html"
   fi
   rm -rf $od
done

exit 0

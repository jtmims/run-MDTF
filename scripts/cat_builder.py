# Currently, certain flags are missing from the catalog builder.
# This makes using a script driver useful

import sys, os 

git_package_dir = sys.argv[1]
sys.path.append(git_package_dir)
import catalogbuilder
from catalogbuilder.scripts import gen_intake_gfdl

#This is an example call to run catalog builder using a yaml config file.
input_path = sys.argv[2]
output_path = sys.argv[3]

def create_catalog(input_path=input_path,output_path=output_path):
    csv, json = gen_intake_gfdl.create_catalog(
                                               input_path=input_path,
                                               output_path=output_path,
                                               verbose=False,
                                               overwrite=True
                                              )
    return(csv,json)

if __name__ == '__main__':
    create_catalog(input_path,output_path)

#  ^..^
# /o  o\   
# oo--oo~~~


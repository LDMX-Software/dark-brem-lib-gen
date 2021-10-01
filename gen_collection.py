"""Generate a collection of dark brem event libraries using the UMN HTCondor batch system"""

import os
import argparse
from umn_htcondor.utility import local_dir, hdfs_dir
from umn_htcondor.submit import JobInstructions

parser = argparse.ArgumentParser('python3 gen_collection.py',
    description='Generate a collection of dark brem event libraries',
    formatter_class=argparse.RawDescriptionHelpFormatter)

parser.add_argument('-s',metavar='SING_IMG',dest='singularity_img',required=True,help='dark-brem-lib-gen image to use for generation.')
parser.add_argument('-t','--target',choices=['tungsten','silicon'],required=True,help='Target material for leptons to be fired at.')
parser.add_argument('-l','--lepton',choices=['electron','muon'],required=True,help='Lepton to do the dark brem.')
parser.add_argument('-m','--max_energy',type=float,required=True,help='Maximum incident lepton energy in GeV.')

parser.add_argument('--no_check',action='store_true',help='Don\' check with user before submitting.')

arg = parser.parse_args()

# hard-coded parameters
start_run = 2000
num_libs_per_mass = 50
mass_points = [0.001, 0.01, 0.1, 1.0] #A' mass points [GeV]
scorpions_with_small_scratch = [1,3,5,6,9,10,11,12,14,16,17,18,20,21,22,23,24]

collection_dir = f'{hdfs_dir()}/dark-brem-event-libraries/{arg.max_energy:.1f}GeV_{arg.lepton}_{arg.target}/'
singularity_img = os.path.realpath(arg.singularity_img)
run_script = os.path.realpath(f'{local_dir()}/umn-specific/batch/run_db_lib_gen.sh')

jobs = []
for m in mass_points :
    jobs.extend([{'apmass' : str(m), 'run' : str(r)} for r in range(start_run, start_run+num_libs_per_mass)])

img_args = f'--target {arg.target} --lepton {arg.lepton} --max_energy {arg.max_energy}'
job_instructions = JobInstructions(run_script, collection_dir, singularity_img, None, program = None,
    input_arg_name = '', extra_config_args = img_args)

for s in scorpions_with_small_scratch :
    job_instructions.ban_machine(f'scorpion{s}')

job_instructions.run_over(' --apmass $(apmass) --run $(run)', jobs)

if arg.no_check :
    job_instructions.submit()
else :
    job_instructions.submit_interactive()



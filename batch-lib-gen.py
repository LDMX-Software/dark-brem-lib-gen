#!/usr/bin/env python

import time
import argparse
import os, sys
import subprocess

# Parse command line arguments
parser = argparse.ArgumentParser(
        'python %s'%sys.argv[0],
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)

# required args
parser.add_argument("-s","--singularity_img",required=True,type=str,help="Image to run configuration inside of.")
parser.add_argument("-o","--out_dir",required=True,type=str,help="Directory to copy output to.")
parser.add_argument("-n","--num_jobs",required=True,type=int,help="Number of jobs to run (if not input directory given).")
parser.add_argument("-A","--ap_mass",required=True,type=float,help="A' mass [GeV] to generate a library for.")

# optional args
parser.add_argument("--start_job",type=int,default=0,help="Starting number to use when counting jobs (and run numbers)")

# rarely-used optional args
parser.add_argument("-t","--test",action='store_true',dest='test',help="Don't submit the job to the batch.")
parser.add_argument("--batch_cmd",type=str,help="Command to use to submit a single job to batch.",default="bsub -R 'select[centos7]' -q medium -W 2800")
parser.add_argument("--incident_energies",type=str,help="String list of incident electron energies.",default="4.0 3.8 3.5 3.2 3.0 2.8 2.5 2.0")

args = parser.parse_args()

# working script requires full paths so we get them here
out_dir = os.path.realpath(args.out_dir)
singularity_img = os.path.realpath(args.singularity_img)

# Turn off emailing about jobs
email_command = ['bash', '-c', 'export LSB_JOB_REPORT_MAIL=N && env']
proc = subprocess.Popen(email_command,stdout=subprocess.PIPE)

for line in proc.stdout: 
    (key, _, value) = line.partition('=')
    os.environ[key] = value.strip()

proc.communicate()

scratch_dir = '/scratch/%s'%os.environ['USER']

# Write the command to submit to the batch system, this includes everything except the per-job changes
command  ="mkdir -p {scratch_dir} && " #make sure scratch directory exists
command +="singularity run --no-home " #run command
command +="--bind {out_dir},{scratch_dir}:/working_dir " #bindings to real space
command +="{singularity_img} " #container image to run int
command +="--out {out_dir} " #define directory to copy generated library to
command +="--energy {energies} " #define space-separated list of incident energies to run at
command +="--nevents {num_events} " #define number of events
command +="--apmass {ap_mass} " #define the A' mass [GeV]
command +="--run {run} " #define run number (acts as random seed)
command +="-v" #verbose so that the log is in the batch system

# Actually start submitting jobs
for job in xrange(args.start_job,args.start_job+args.num_jobs):

    # wait until the number of jobs pending is <= 5
    if not args.test:
        pendingCount = int(subprocess.check_output('bjobs -p 2> /dev/null | wc -l', shell=True))
        while pendingCount > 5 : 
            sys.stdout.write( 'Total jobs pending: %s\r' % pendingCount )
            sys.stdout.flush()
            time.sleep(1)
            pendingCount = int(subprocess.check_output('bjobs -p 2> /dev/null | wc -l',shell=True))

        if pendingCount > 0 :
            time.sleep(10)
    #end if not test

    specific_command = command.format(
        out_dir = out_dir,
        scratch_dir = scratch_dir,
        singularity_img = singularity_img,
        energies = args.incident_energies,
        ap_mass = args.ap_mass,
        num_events = 20000,
        run = job
        )

    full_cmd="{batch_cmd} '{run_cmd}'".format(
            batch_cmd = args.batch_cmd,
            run_cmd = specific_command
            )

    if args.test: 
        print(full_cmd)
    else:
        subprocess.Popen(full_cmd,shell=True).wait()
        time.sleep(1)
    #end whether or not is a test
#end loop through jobs

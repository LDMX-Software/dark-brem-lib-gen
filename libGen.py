
import argparse, sys

###############################################################################
# Import and parse the CLI arguments

parser = argparse.ArgumentParser(sys.argv[0])

parser.add_argument(
        "-r",
        dest="runNumbers",
        nargs='*', # 0 or more args
        default=[ 3000 ],
        help='List of run numbers to use. Use to expand library if need larger sample size.'
        )
parser.add_argument(
        "-n","--nevents",
        dest="nevents",
        default=20000,
        type=int,
        help='Number of events to generate per entry in library.'
        )
parser.add_argument(
        "-t","--test",
        dest="test",
        default=False,
        action='store_true',
        help="Just print command instead of running it."
        )

arg = parser.parse_args()


###############################################################################
# List of parameters for dictionary
# They are hardcoded to be strings because this script only uses them as strings

# A' masses in GeV
apMasses = [ '1.0' , '0.1' , '0.05' , '0.01' , '0.005' , '0.001' ]

# electron beam energy in GeV
beamEnergies = [ 
        '4.0' , '3.8' , '3.5' , '3.0' , '2.5' , '2.0' 
        #, '1.5' , '1.0' , '0.5' , '0.25' , '0.125' , '0.0625' , '0.03125'
        ]

###############################################################################
# Loop through A' mass and beam energy selections
#   Careful, this is three nested for loops, could get out of hand pretty
#   quick. Might want to force myself to only have one A' mass?
###############################################################################
import subprocess, glob
for mA in apMasses :
    for beamE in beamEnergies :
        
        # skip if not physically possible
        if mA >= beamE :
            continue 

        for run in arg.runNumbers :

            # check if already been made
            globCmd = 'lhe/mA.%s/*%s*%s*'%( mA , beamE , run )
            candidateFiles = glob.glob( globCmd )
            if len(candidateFiles) > 0 :
                print '[ libGen.py ] : %s has already been simulated.' % ( candidateFiles[0] )
                continue

            command = "./run.sh %s %s %s %s" % ( mA , beamE , run , arg.nevents )

            if arg.test :
                print command
            else :
                # run the bash script and wait
                subprocess.Popen( command , shell=True ).wait()

        #end loop over run numbers
    #end loop over beam energies
#end loop over A' masses

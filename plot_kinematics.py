"""Plot kinematics of dark brem LHE files

"""

import matplotlib
import matplotlib.pyplot as mpl
import math
from dark_brem_lhe import DarkBremFile

# this takes a relatively long time
import sys, os
files = [DarkBremFile(os.path.join(sys.argv[1],f)) for f in os.listdir(sys.argv[1]) if f.endswith('lhe')]

for f in files :
    mpl.hist(
        f.dark_photon.e / f.incident_energy,
        bins = 200,
        range = (0.,1.),
        histtype = 'step'
        )
mpl.savefig('dark_photon_energy.pdf')
mpl.clf()

for f in files :
    mpl.hist(
        f.recoil_lepton.e / f.incident_energy,
        bins = 200,
        range = (0.,1.),
        histtype = 'step'
        )
mpl.savefig('recoil_lepton_energy.pdf')
mpl.clf()

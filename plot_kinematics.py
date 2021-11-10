"""Plot kinematics of dark brem LHE files"""

import matplotlib
import matplotlib.pyplot as mpl
import math
import os
import numpy
import dark_brem_lhe


def plot(dblib_d, output_d = 'plots') :
    """Plot the kinematic distributions in the dark brem lib

    Parameters
    ----------
    dblib_d : str
        Path to dark brem event library to plot
    """

    # this takes a relatively long time
    dblib = dark_brem_lhe.DarkBremEventLibrary(dblib_d)
    os.makedirs(output_d, exist_ok = True)

    # dark photon kinematics

    for f in dblib.files :
        mpl.hist(
            f.events.dark_photon.e / f.incident_energy,
            bins = 200,
            range = (0.,1.),
            histtype = 'step',
            label = f'{f.incident_energy} GeV Leptons',
            log = True
            )
    mpl.ylabel('Events')
    mpl.xlabel('Dark Photon Energy Fraction')
    mpl.legend(loc='upper left')
    mpl.title(str(dblib))
    mpl.savefig(f'{output_d}/dark_photon_energy.pdf')
    mpl.clf()

    for f in dblib.files :
        mpl.hist(
            dark_brem_lhe.costheta(f.events.dark_photon),
            bins = 200,
            range = (-1,1),
            histtype = 'step',
            label = f'{f.incident_energy} GeV Leptons',
            log = True
            )
    mpl.ylabel('Events')
    mpl.xlabel('Dark Photon cos(theta)')
    mpl.legend(loc = 'upper left')
    mpl.title(str(dblib))
    mpl.savefig(f'{output_d}/dark_photon_costheta.pdf')
    mpl.clf()

    for f in dblib.files :
        mpl.hist(
            dark_brem_lhe.cosphi(f.events.dark_photon),
            bins = 200,
            range = (-1,1),
            histtype = 'step',
            label = f'{f.incident_energy} GeV Leptons',
            log = True
            )
    mpl.ylabel('Events')
    mpl.xlabel('Dark Photon cos(phi)')
    mpl.legend(loc = 'upper left')
    mpl.title(str(dblib))
    mpl.savefig(f'{output_d}/dark_photon_cosphi.pdf')
    mpl.clf()

    # recoil lepton kinematics
    
    for f in dblib.files :
        mpl.hist(
            f.events.recoil_lepton.e / f.incident_energy,
            bins = 200,
            range = (0.,1.),
            histtype = 'step',
            label = f'{f.incident_energy} GeV Leptons',
            log = True
            )
    mpl.ylabel('Events')
    mpl.xlabel('Recoil Lepton Energy Fraction')
    mpl.legend(loc='upper left')
    mpl.title(str(dblib))
    mpl.savefig(f'{output_d}/recoil_lepton_energy.pdf')
    mpl.clf()

    for f in dblib.files :
        mpl.hist(
            dark_brem_lhe.costheta(f.events.recoil_lepton),
            bins = 200,
            range = (-1,1),
            histtype = 'step',
            label = f'{f.incident_energy} GeV Leptons',
            log = True
            )
    mpl.ylabel('Events')
    mpl.xlabel('Recoil Lepton cos(theta)')
    mpl.legend(loc = 'upper left')
    mpl.title(str(dblib))
    mpl.savefig(f'{output_d}/recoil_lepton_costheta.pdf')
    mpl.clf()

    for f in dblib.files :
        mpl.hist(
            dark_brem_lhe.cosphi(f.events.recoil_lepton),
            bins = 200,
            range = (-1,1),
            histtype = 'step',
            label = f'{f.incident_energy} GeV Leptons',
            log = True
            )
    mpl.ylabel('Events')
    mpl.xlabel('Recoil Lepton cos(phi)')
    mpl.legend(loc = 'upper left')
    mpl.title(str(dblib))
    mpl.savefig(f'{output_d}/recoil_lepton_cosphi.pdf')
    mpl.clf()

if __name__ == '__main__' :
    import sys
    # CLI arguments are same as arguments to plot
    plot(*sys.argv[1:])

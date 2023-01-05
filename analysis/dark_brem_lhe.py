"""Read dark brem LHE files

We use the pylhe Python module developed by scikit-hep
to parse the LHE files here.

  https://github.com/scikit-hep/pylhe

pylhe API Notes
---------------
Currently, the head of the master branch has diverged
from the last release pretty significantly, so make sure
you are on the current release tag when browsing the GitHub.

readLHE returns a generator for looping over the events.

LHEEvent 
  'particles' attribute which has the list of particles.

LHEParticle
  'e' Energy
  'px', 'py', 'pz' 3 Momentum 
  'status' incoming/outgoing effectively
  'id' pdg ID
"""

import pylhe
import numpy
import pandas
import os

class DarkBremEvent :
    """A Dark Brem event parsed from the LHE file

    This is an incredibly simple class which handles
    the assignment of physicist-helpful names to the particles
    in the LHE event.
    
    Attributes
    ----------
    dark_photon : pylhe.LHEParticle
        The outgoing dark photon - particle ID is 622
    incident_lepton : pylhe.LHEParticle
        The incoming lepton incident on the nuclear target
        Particle ID is 11 or 13 and status is negative
    recoil_lepton : pylhe.LHEParticle
        The recoiling lepton
        Particle ID is 11 or 13 and status is positive
    """

    def __init__(self, lhe_event) :
        for particle in lhe_event.particles :
            if particle.id == 622 :
                self.dark_photon = particle

            if particle.id == 11 or particle.id == 13 :
                if particle.status < 0 :
                    self.incident_lepton = particle
                elif particle.status > 0 :
                    self.recoil_lepton = particle

def read_dark_brem_lhe(lhe_file) :
    """Generator of DarkBremEvents from the input LHE file

    This simply wraps the pylhe.readLHE python generator
    by wrapping their output event with our own event.
    """

    for lhe_event in pylhe.readLHE(lhe_file) :
        yield DarkBremEvent(lhe_event)

class DarkBremEventFile :
    """In-memory storage of dark brem event kinematics for the input file

    After reading in some initialization parameters,
    we read in **all** of the events in the file.
    
    For some god-foresaken reason, the line in the MGGenerationInfo block
    labeled 'Integrated weight (pb)' and the entry in the init block that
    is the integrated weight by the schema definition are not the same always.
    
    We are choosing to just always use the MGGenerationInfo block one.
    This unfortunately requires a third parsing of the document.
    
    Attributes
    ----------
    lepton : int
        11 (electron) or 13 (muon), pdg of lepton
    incident_energy : float
        Incident energy of lepton [GeV]
    target : int
        Integer ID for target nucleus (e.g. we've been using -623 for tungsten)
        WARNING: This may not change if we are only changing the target mass for different target materials
    target_mass : float
        Mass of target nucleus [GeV]
    xsec : float
        total cross section for the events in this file
    events : pandas.DataFrame
        DataFrame of events in this file
    """

    def __init__(self, lhe_file) :
        self.full_init_info = pylhe.readLHEInit(lhe_file)
        self.lepton = int(self.full_init_info['initInfo']['beamA'])
        self.incident_energy = self.full_init_info['initInfo']['energyA']
        self.target = int(self.full_init_info['initInfo']['beamB'])
        self.target_mass = self.full_init_info['initInfo']['energyB']
        
        with open(lhe_file) as text :
            matches = [l for l in text.readlines() if 'Integrated' in l]
            if len(matches) != 1 :
                raise KeyError(f'More than one line in {lhe_file} with Integrated in it.')
            self.xsec = float(matches[0].split()[-1])
        
        event_data = []
        for e in read_dark_brem_lhe(lhe_file) :
            event_data.append({
                'x' : 0.,
                'y' : 0.,
                'z' : 0.,
                'incident_pdg' : e.incident_lepton.id,
                'incident_genstatus' : e.incident_lepton.status,
                'incident_mass' : e.incident_lepton.m,
                'incident_energy' : e.incident_lepton.e,
                'incident_px' : e.incident_lepton.px,
                'incident_py' : e.incident_lepton.py,
                'incident_pz' : e.incident_lepton.pz,
                'recoil_pdg' : e.recoil_lepton.id,
                'recoil_genstatus' : e.recoil_lepton.status,
                'recoil_mass' : e.recoil_lepton.m,
                'recoil_energy' : e.recoil_lepton.e,
                'recoil_px' : e.recoil_lepton.px,
                'recoil_py' : e.recoil_lepton.py,
                'recoil_pz' : e.recoil_lepton.pz,
                'aprime_pdg' : e.dark_photon.id,
                'aprime_genstatus' : e.dark_photon.status,
                'aprime_mass' : e.dark_photon.m,
                'aprime_energy' : e.dark_photon.e,
                'aprime_px' : e.dark_photon.px,
                'aprime_py' : e.dark_photon.py,
                'aprime_pz' : e.dark_photon.pz,
            })
        self.events = pandas.DataFrame(event_data)

    def __repr__(self) :
        return f'DarkBremEventFile(lepton=[{self.lepton},{self.incident_energy}GeV],target=[{self.target},{self.target_mass}GeV])'

class DarkBremEventLibrary :
    """In-memory storage of dark brem event kinematics for an event library

    We basically hold all of the DarkBremEventFiles in one place.

    Attributes
    ----------
    lepton : int
        11 (electron) or 13 (muon), pdg of lepton
    incident_energy : float
        Incident energy of lepton [GeV]
    target : int
        Integer ID for target nucleus (e.g. we've been using -623 for tungsten)
        WARNING: This may not change if we are only changing the target mass for different target materials
    target_mass : float
        Mass of target nucleus [GeV]
    files : list
        List of DarkBremEventFiles in this library
    """

    def __init__(self, library_d, *,
                 filt_substr = None) :
        self.files = [
            DarkBremEventFile(os.path.join(library_d,f)) 
            for f in os.listdir(library_d) if 
            f.endswith('lhe') and (filt_substr is None or filt_substr in f)
        ]
        if len(self.files) == 0 :
            raise Exception(f'Passed library {library_d} does not have any LHE files in it.')

        self.lepton = self.files[0].lepton
        self.incident_energy = self.files[0].incident_energy
        self.target = self.files[0].target
        self.target_mass = self.files[0].target_mass

        for dbf in self.files :
            if (
                self.lepton != dbf.lepton or 
                self.target != dbf.target or 
                self.target_mass != dbf.target_mass 
               ) :
                raise Exception('One of the LHE files in the passed library does not match configuration of the others.')

        # sort by incident energy
        self.files.sort(reverse = True, key = lambda f : f.incident_energy)

        self.lepton_str = 'Electrons'
        if self.lepton == 13 :
            self.lepton_str = 'Muons'

    def __repr__(self) :
        return f'DarkBremEventLibrary(lepton={self.lepton_str},target=[{self.target},{self.target_mass}GeV])'

    def __str__(self) :
        return f'Dark Brem Event Library of {self.lepton_str} on {self.target_mass} GeV Target'
    
    def events(self) :
        """Get all of the events in this library in a single dataframe"""
        return pandas.concat([f.events for f in self.files])
    
    def total_xsec(self) :
        """Get the table of incident energies vs total cross section"""
        return pandas.DataFrame(data={
            'energy' : [f.incident_energy for f in self.files],
            'xsec' : [f.xsec for f in self.files]
        })
    
if __name__ == '__main__' :
    import argparse
    parser = argparse.ArgumentParser(
        description="""
        extract event kinematic and total cross section information
        from a directory of LHE files into a single HDF5 file with
        two pandas DataFrames stored inside
        """
    )
    parser.add_argument('dir',
                        help='directory of MG LHE files to retrieve')
    parser.add_argument('--filter',
                        help='string to filter out only some of the LHE files in the directory')
    parser.add_argument('--output',
                        help='define desitination HDF5 file to store dataframes')
    
    arg = parser.parse_args()
    
    if arg.dir.endswith('/') :
        arg.dir = arg.dir[:-1]
    output = arg.dir+'.h5'
    if arg.output is not None :
        output = arg.output
    
    dbel = DarkBremEventLibrary(arg.dir, filt_substr = arg.filter)
    dbel.events().to_hdf(output, 'events')
    dbel.total_xsec().to_hdf(output, 'total_xsec')

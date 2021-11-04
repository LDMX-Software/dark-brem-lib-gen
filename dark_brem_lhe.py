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
import os

class ColumnList(list) :
    """Wrapper around a list of objects
    so we can grab lists of those member variables.

    We assume that the member variable requested from
    each of the objects is a low-level number (e.g. float)
    so that we can wrap the values in a numpy array.
    """

    def __getattr__(self, name) :
        """Called after everything else,
        we assume we are trying to get all entries for a specific
        attribute of the entries in this list.

        Fundamental types don't have the '__dict__' attribute,
        so if the list is empty or the first entry has the '__dict__'
        attribute, we return a ColumnList of the requested attribute.
        Otherwise, we return a numpy.array of the requested attribute
        (i.e. assuming that it is the last request).
        """
        raw_list = [getattr(o,name) for o in self]

        if len(raw_list) == 0 :
            return raw_list

        if isinstance(raw_list[0], ColumnList) :
            return ColumnList([item for sublist in raw_list for item in sublist])

        if hasattr(raw_list[0],'__dict__') :
            return ColumnList(raw_list)

        return numpy.array(raw_list)

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
    recoil_lepton : pylhe.LHEParticle
        The outgoing lepton
    dark_photon : pylhe.LHEParticle
        The outgoing dark photon
    events : ColumnList
        List of DarkBremEvents in this file, wrapped with column list to make retrieval of data easier
    """

    def __init__(self, lhe_file) :
        self.full_init_info = pylhe.readLHEInit(lhe_file)
        self.lepton = int(self.full_init_info['initInfo']['beamA'])
        self.incident_energy = self.full_init_info['initInfo']['energyA']
        self.target = int(self.full_init_info['initInfo']['beamB'])
        self.target_mass = self.full_init_info['initInfo']['energyB']
        self.events = ColumnList(read_dark_brem_lhe(lhe_file))

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
    files : ColumnList
        List of DarkBremEventFiles in this library, wrapped with column list to make retrieval of data easier
    """

    def __init__(self, library_d) :
        self.files = ColumnList([DarkBremEventFile(os.path.join(library_d,f)) for f in os.listdir(library_d) if f.endswith('lhe')])
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

    def __repr__(self) :
        return f'DarkBremEventLibrary(lepton={self.lepton},target=[{self.target},{self.target_mass}GeV])'

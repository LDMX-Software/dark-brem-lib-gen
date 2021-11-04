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

class ColumnList :
    """Wrapper around a list of objects
    so we can grab lists of those member variables.

    We assume that the member variable requested from
    each of the objects is a low-level number (e.g. float)
    so that we can wrap the values in a numpy array.
    """
    def __init__(self, l) :
        self.__list = l

    def __getattr__(self, name) :
        """Called after everything else,
        we assume we are trying to get all entries for a specific
        attribute of the particles in this list.

        Fundamental types don't have the '__dict__' attribute,
        so if the list is empty or the first entry has the '__dict__'
        attribute, we return a ColumnList of the requested attribute.
        Otherwise, we return a numpy.array of the requested attribute
        (i.e. assuming that it is the last request).
        """
        raw_list = [getattr(o,name) for o in self.__list]
        if len(raw_list) == 0 or hasattr(raw_list[0],'__dict__') :
            return ColumnList(raw_list)
        else :
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

    fieldnames = ['recoil_lepton','dark_photon','incident_lepton']

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

class DarkBremFile :
    """In-memory storage of dark brem event kinematics for the input file

    After reading in some initialization parameters,
    we read in **all** of the events in the file.
    When a getattr call is made and all other options are exhausted,
    we assume we want an object from the list of events.
    
    Attributes
    ----------
    lepton : int
        11 (electron) or 13 (muon), pdg of lepton
    incident_energy : float
        Incident energy of lepton [GeV]
    recoil_lepton : pylhe.LHEParticle
        The outgoing lepton
    dark_photon : pylhe.LHEParticle
        The outgoing dark photon
    """

    def __init__(self, lhe_file) :
        self.full_init_info = pylhe.readLHEInit(lhe_file)
        self.lepton = int(self.full_init_info['initInfo']['beamA'])
        self.incident_energy = self.full_init_info['initInfo']['energyA']
        self.events = ColumnList([e for e in read_dark_brem_lhe(lhe_file)])

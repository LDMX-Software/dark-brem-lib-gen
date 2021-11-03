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

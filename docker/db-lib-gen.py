"""Generate a Dark-Brem event library using MadGraph 4"""

import argparse
import os
import gzip
import shutil
import tarfile
import subprocess
import sys

target_options = {
    'tungsten' : { 'mass' : 171.3, 'A' : 184.0, 'Z' : 74.0 },
    'silicon'  : { 'mass' : 26.15, 'A' : 28.08, 'Z' : 14.0 },
    }

lepton_options = {
    'electron' : { 'mass' : 0.000511, 'pdg' : '11' },
    'muon' : { 'mass' : 0.10565837, 'pdg' : '13' }
    }

def in_singularity() :
    return os.path.isfile('/singularity')

class SafeDict(dict) :
    """ Idea for this type of look-up dictionary is provided by
    https://stackoverflow.com/a/17215533

    Basically, we skip any keys that don't have values by leaving
    the key (with the curly-braces) in the file.
    """
    def __missing__(self, key) :
        return '{'+key+'}'

def write(fp, **kwargs) :
    template_f = f'{fp}.tmpl'
    if not os.path.isfile(template_f) :
        raise Exception(f'{fp} does not have an template file.')
    # get file template
    with open(fp+'.tmpl','r') as f :
        t = f.read()
    # insert values
    t = t.format_map(SafeDict(**kwargs))
    # write file content
    with open(fp,'w') as f :
        f.write(t)

def generate() :
    parser = argparse.ArgumentParser('python3 db-lib-gen.py',
            formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    
    parser.add_argument('--pack',default=False,action='store_true',
        help='Package the library into a tar-ball after it is written to the output directory.')
    parser.add_argument('--out_dir',default=os.getcwd(),
        help='Directory to output library archive.')
    parser.add_argument('--run',default=3000,type=int,
        help='Run number for MadGraph which acts as the random number seed.')
    parser.add_argument('--nevents',default=20000,type=int,
        help='Number of events per sampling point to generate.')

    parser.add_argument('--max_energy',default=4.0,type=float,
        help='Maximum energy of the incident lepton beam in GeV')
    parser.add_argument('--min_energy',default=None,type=float,
        help='Miminum energy of the incident lepton beam in GeV (default is half max).')
    parser.add_argument('--rel_step',default=0.1,type=float,
        help='Relative step size between sampling points in library.')
    parser.add_argument('--max_recoil',default='1d5',
        help='Maximum energy the recoil lepton is allowed to have in GeV.')
    parser.add_argument('--apmass',default=0.01,type=float,
        help='Mass of the dark photon (A\') in GeV')
    parser.add_argument('--target',default='tungsten',choices=target_options.keys(),
        help='Target material to shoot leptons at.')
    parser.add_argument('--lepton',default='electron',choices=lepton_options.keys(),
        help='Leptons to shoot.')

    arg = parser.parse_args()

    lepton = lepton_options[arg.lepton]
    target = target_options[arg.target]

    library_name=f'{arg.lepton}_{arg.target}_MaxE_{arg.max_energy}_MinE_{arg.min_energy}_RelEStep_{arg.rel_step}_UndecayedAP_mA_{arg.apmass}_run_{arg.run}'
    library_dir=os.path.join(arg.out_dir,library_name)

    os.makedirs(arg.out_dir, exist_ok = True)
    os.makedirs(library_dir, exist_ok = True)

    if in_singularity() :
        # move to /working_dir
        new_working_dir=f'/working_dir/{library_name}'
        os.makedirs(new_working_dir)
        shutil.copytree('/madgraph',new_working_dir)
        os.chdir(f'{new_working_dir}/madgraph/')
    # done with movement

    os.environ['LD_LIBRARY_PATH'] = f'{os.environ["LD_LIBRARY_PATH"]}:{os.getcwd()/lib}'

    write('Cards/param_card.dat', 
        ap_mass = arg.apmass, 
        lepton_mass = lepton['mass'],
        target_Z = target['Z'], 
        target_mass = target['mass'])

    write('Source/MODEL/couplings.f',
        target_A = target['A'])

    min_energy = arg.max_energy/2.
    if arg.min_energy is not None :
        min_energy = arg.min_energy

    energy = arg.max_energy
    while energy > min_energy*(1.-arg.rel_step) :
        write('Cards/run_card.dat',
            nevents = arg.nevents,
            run = arg.run,
            lepton_energy = energy,
            lepton_mass = lepton_options[arg.lepton]['mass'],
            max_recoil_energy = arg.max_recoil,
            target_mass = target_options[arg.target]['mass'])

        prefix = f'{library_name}_IncidentEnergy_{energy}'

        subprocess.run(['./bin/generate_events','0',prefix],check = True)

        with gzip.open(f'Events/{prefix}_unweighted_events.lhe.gz','rt') as zipped_lhe :
            with open(f'{library_dir}/{prefix}_unweighted_events.lhe','w') as lhe :
                # translate PDGs of 11 to correct lepton PDG just in case we ran with muons
                content = zipped_lhe.read().replace(' 11 ',f' {lepton["pdg"]} ')
                lhe.write(content)

        energy *= 1.-arg.rel_step

    if arg.pack :
        with tarfile.open(f'{arg.out_dir}/{library_name}.tar.gz','w:gz') as tar_handle :
            tar_handle.add(library_dir)

        shutil.rmtree(library_dir)

    if in_singularity() :
        shutil.rmtree(new_working_dir)

if __name__ == '__main__' :
    generate()


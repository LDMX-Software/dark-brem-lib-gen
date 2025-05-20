
# Dark Brem Event Generation
This repository stores the build context for a container image which holds a specific instance of MadGraph
designed to generate dark bremsstrahlung events over a range of incident lepton energies. Specifically,
the output of running this container is a "library" of dark brem events which can be used within
[G4DarkBreM](https://github.com/LDMX-Software/G4DarkBreM).

## Quick Start
If you aren't developing the container and just wish to use it,
you do not need to clone this repository.
You can simply use the image this repository creates with `denv`.

First, choose a version of dark-brem-lib-gen to use.
The version must be >= 5.1 for the following run command to function,
but using an older version can be done with ease as well (see below).
```
denv init ldmx/dark-brem-lib-gen:v5.1
```

Run the library generation from within this initialized environment.
```
denv db-lib-gen --help
```

## Usage Manual
This section lists the different command line options with a bit more explanation than what the command line itself has room for.

`--out-dir` tells the script where to put the "library" (directory of generated LHE files). This directory needs to be a location that is mounted to the container spawned by `denv`. (Use `denv config mounts` to add a directory if needed.)

`--scratch` tells the script where to put scratch files. The scratch directory is only necessary when running with Singularity or Apptainer and defaults to the `db-lib-gen-scratch` subdirectory of the denv workspace directory (which is a good default unless you are running `denv` on a space-limited or slow filesystem).

`--pack` instructs the script to package the directory of generated LHE files into a tar-ball (`.tar.gz` file) after they are all written to the output directory. This can be helpful if the newly-generated library needs to be moved immediately after generation since it is generally easier to move only one file that a directory of files.

`--run` changes the run number for MadGraph which is used as its random seed. This should be changed if multiple libraries with the same parameters wish to be generated for larger signal samples.

`--nevents` sets the number of events _for each_ energy point in the library. Generally, MadGraph (especially MadGraph4) is limited to under 100k events for each random seed that is used and so the default of 20k is a reasonable number.

`--max-energy` sets the highest energy (in GeV) to be put into the reference library.

`--min-energy` sets the minimum energy (in GeV) to be put into the reference library. The default is half of the maximum energy.

`--rel-step` sets the relative step size between different energy sampling points in the library. The default is 0.1 (or 10%) which was determined qualitatively by looking at distributions studying the scaling behavior implemented in G4DarkBreM.

`--max-recoil` sets the maximum energy (in GeV) a recoil lepton is allowed to have. The default is `1d5` (or no maximum in MadGraph4). This has not been studied in any detail and could very easily not be doing what I think it is doing.

`--apmass` sets the mass of the dark photon (in GeV) for MadGraph to use in the dark brem.

`--target` sets the target material(s) to shoot leptons at. If more than one material is provided, then the library will contain all of the configured energy sample points for each of the different materials. The available materials are shown in the help message - other materials can be added once the mass of the nucleus (in GeV), the atomic mass (in amu), and the atomic number are known.

`--lepton` sets the lepton to shoot (either electrons or muons).

## context

<a href="https://github.com/LDMX-Software/dark-brem-lib-gen/actions" alt="Actions">
    <img src="https://github.com/LDMX-Software/dark-brem-lib-gen/workflows/CI/badge.svg" />
</a>

This directory contains the actual build context for a docker image that can run the necessary [MadGraph](https://cp3.irmp.ucl.ac.be/projects/madgraph/) event generation script.
Currently, the MadGraph event generation can handle the following variables.

- Number of Events to Generate
- Mass of A' in GeV
- Target material (from list of options)
- Lepton (muon or electron)
- Maximum and Minimum Incident Beam Energy in GeV
- Relative step between sampling points in library
- Run Number (used as random number seed) 

The corresponding DockerHub repository for this image is [ldmx/dark-brem-lib-gen](https://hub.docker.com/repository/docker/ldmx/dark-brem-lib-gen).

## analysis
A helpful python module for analyzing the dark brem event libraries separately from ldmx-sw.

# Batch Running
The environment script is able to deduce if it is in a non-interactive environment, 
so it can be used within another script to (for example) use within a batch processing
system. For example, a script I use with [HTCondor](https://htcondor.readthedocs.io/en/latest/) 
is below. The path `/full/path/to/shared/location` is the full path to a filesystem shared
across all worker nodes.

```bash
#!/bin/bash
set -ex
# initialize dbgen environment
# use a pre-built SIF file to avoid overloading DockerHub's pull limit
denv init /full/path/to/shared/location/dark-brem-lib-gen_v5.0.sif
# run with the arguments to this script
denv db-lib-gen $@

# condor doesn't scan subdirectories so we should move the LHE files here
#  you could avoid this nonsense with some extra condor config
find \
  -type f \
  -name "*.lhe" \
  -exec mv {} . ';'
```

# Using Old Versions
The infrastructure change that enables easy usage via `denv` is providing
the output (and scatch) directories on the command line to the `db-lib-gen.py`
python script instead of assuming they are mounted to `/output` and `/working`
respectively.

You can still use an old version of the MadGraph event generation by making this
interface update to the central steering python script of that version.
Below is a rough outline of the procedure you can follow using v4.0 as an example.
```sh
# 1. create a denv workspace with v4.0
denv init ldmx/dark-brem-lib-gen:v4.0
# 2. copy the steering script here for editing
denv cp /madgraph/db-lib-gen.py .
# 3. edit db-lib-gen.py to accept directories on command line
# The output of
#   denv diff /madgraph/db-lib-gen.py db-lib-gen.py
# is copied below
# 4. Run with the updated steering script
denv python3 ./db-lib-gen.py
```

<details>
<summary>Updates to `db-lib-gen.py` for v4.0</summary>

```diff
--- /madgraph/db-lib-gen.py
+++ db-lib-gen.py
@@ -48,6 +48,10 @@
     parser = argparse.ArgumentParser('dbgen run',
             formatter_class=argparse.ArgumentDefaultsHelpFormatter)
     
+    from pathlib import Path
+    parser.add_argument('--out_dir',default=Path.home())
+    parser.add_argument('--scratch',default=(Path.home() / 'scratch'))
+
     parser.add_argument('--pack',default=False,action='store_true',
         help='Package the library into a tar-ball after it is written to the output directory.')
     parser.add_argument('--run',default=3000,type=int,
@@ -79,21 +83,21 @@
     if arg.min_energy is not None :
         min_energy = arg.min_energy
 
-    # user mounts output directory to specific location in container
-    out_dir = '/output'
-
     library_name=f'{arg.lepton}_{arg.target}_MaxE_{arg.max_energy}_MinE_{min_energy}_RelEStep_{arg.rel_step}_UndecayedAP_mA_{arg.apmass}_run_{arg.run}'
-    library_dir=os.path.join(out_dir,library_name)
+    library_dir= (arg.out_dir / library_name)
 
-    os.makedirs(out_dir    , exist_ok = True)
-    os.makedirs(library_dir, exist_ok = True)
+    arg.out_dir.mkdir(exist_ok=True)
+    library_dir.mkdir(exist_ok=True)
 
+    arg.out_dir = arg.out_dir.resolve()
+    library_dir = library_dir.resolve()
+
     # make sure we are in the correct directory
     os.chdir('/madgraph')
 
     if in_singularity() :
-        # move to /working_dir
-        new_working_dir=f'/working/{library_name}'
+        # move to scratch
+        new_working_dir = arg.scratch / library_dir
         shutil.copytree('/madgraph/',new_working_dir)
         os.chdir(new_working_dir)
     # done with movement
```

</details>

### QM/MM APEC Protocol for Flavo-proteins. 

Includes technical details needed for future development:

1.	Before getting started, modify your .bashrc or .bash_profile to include PATH variables from this .bashrc: /userapp/APEC_Kabir/bashrc_backup.

2.	New_APEC.sh (/userapp/APEC_Kabir/New_APEC/New_APEC.sh): This is the first script to run to start a calculation.
To start, all you need is a pdb file. Delete unwanted chains and groups from the pdb (e.g., if the system is a dimer made up of chains A and B and you only want to model the monomer, you can delete chain A). 
The keyword “TER” is used in the PDB to separate the different chains of the protein (A, B, C ..) and to separate the non-standard residues from the protein (like Water, ions, ligands, etc.). If there is only one chain, only one “TER” must be present in the pdb file, separating the ATOM section (protein) from HETATM section (only water molecules are allowed here, no ions, ligands, etc.), otherwise it will be considered as a Multi-chain protein.
Make sure you have the correct protonation states for residues in the pdb. The protonation state is determined by the 3-letter code you use for each amino acid (e.g. GLU is deprotonated (glutamate), while GLH is protonated (glutamic acid). More generally, if you are not sure about the protonation state in your system, you can check literature for any information, or if you find nothing there are programs and ways to predict pKa of a system (e.g. Propka). In addition, all the available protonation states and sidechains can be found here: /userapp/APEC_GOZEM/New_APEC/template/amber99sb.ff/aminoacids.rtp.

The Flavin can appear in the original pdb file and “FMN” or “FAD”. Since they are not standard residues, they have been parametrized in accord to http://amber.manchester.ac.uk. This parametrization is located here for FMN: /userapp/APEC_GOZEM/New_APEC/template/ASEC/manchester_FMN_rtp (This parametrization is used in Step_0, after that the charges are updated using ESPF and the APEC configuration).
The idea is to separate the flavin from the rest of the protein during the first steps of the protocol (dowser, to deal with internal/external water molecules and adding Hydrogens to the protein with Gromacs). When the flavin is needed, it is added to the protein structure. For example, to perform mutations at the very beginning, the chromophore is inserted temporarily into the pdb file (line 252 of /userapp/APEC_GOZEM/New_APEC/template/New_APEC_1.sh).

“New_APEC.sh” has been developed by Pabel, which automatically generate the file CHR_chain.xyz and the clean protein without the FMN or FAD from the original pdb file. Once the CHR_chain.xyz has been created and extracted from the protein, it can be used to start any other protocol run but starting with: /userapp/APEC_GOZEM/New_APEC/template/New_APEC_1.sh”

“seqmut” is a file containing the mutations to be introduced in the protein. SCWRL4 will be used for this purpose in the current version.

3.	NewStep.sh (/userapp/APEC_GOZEM/New_APEC/template/NewStep.sh): The first thing done by this script is to run “Dowser” to remove non-internal water molecules and to add the hydrogens of the backbone. I consider Dowser is not really necessary in the systems that we have study so far because they have a lot of cavities for the waters to get in and out, but I keep it because in the future it can be needed.
A common error fund in Dowser is:

wc: place_xtal_o.dow: No such file or directory
Can't open place_xtal_o.dow file!
/bin/mv: cannot stat ‘chooser.dow’: No such file or directory
wc: place_xtal_o.dow: No such file or directory
W: Subscript out of range.
cat: dowserwat_all.pdb: No such file or directory

This happens when no internal waters are found, and you can go ahead without any problem.

When Dowser is done, the generated pdb file (without external waters and hydrogens only added to the backbone) is converted to gromacs format ($gropath/gmx pdb2gmx …). In this conversion the hydrogens are added to the sidechains automatically.

Templates: When the .gro file is generated we need to create two templates “template_gro2tk” and “template_tk2gro” which are very used in the protocol and used to generate the APEC configuration. These are two columns files, indicating which atom number in one format corresponds to the same atom in the other format. For example, in template_gro2tk:
…
1321  1372  
…
That line indicates that the atom 1321 in the .gro file is the atom 1372 in the .xyz file (tinker)
These two templates are generated in the following order:
•	Convert the .gro file to .pdb using gromacs (this is the .gro file generated after dowser)
•	The .pdb file is converted to tinker file (.xyz) using Tinker.
•	Having the .gro and the corresponding .xyz (remember that they does not contain the Chromophore because it was removed. It will be added letter to the templates) we use the fortran code “Templates_gro_tk.f” to match the atoms with exactly the same xyz coordinates and generate the two templates: “template_gro2tk” and “template_tk2gro”

4.	Solvent_box.sh (/userapp/APEC_GOZEM/New_APEC/template/ASEC/Solvent_box.sh): The Chromophore has not been used so far in the previous steps. Only if performing mutations at the very beginning, in which case the chromophore is temporarily added to the original .pdb file. But no parametrization of the chromophore is needed to do that.
It is time now to add the chromophore to the .gro file because we will start with the MD. The first thing is to ask if it is FMN or FAD and Quinine, semi-quinone or Hydro-quinone to get the right parametrization. We have decided to use the Manchester parametrization for Step_0 and update the charges in the next steps.
So far, it is fully implemented and tested only FMN/Quinone (I plan to add the rest). 
The parametrization is already in rtp format: /userapp/APEC_GOZEM/New_APEC/template/ASEC/manchester_FMN_rtp, so, it is just to add it to amber99sb.ff/aminoacids.rtp.
Adding the chromophore to the .gro file and running the MD is done in the following order:
•	The Chromophore in PDB format is added to the .pdb file generated by Dowser, BETWEEN THE PROTEIN AND THE WATERS SECTIONS (it cannot be altered)
•	Since we already added the parametrization to the amber99sb.ff/aminoacids.rtp file, we can use gromacs with the FMN in the protein:

$gropath/gmx pdb2gmx -f $Project.pdb -o $Project.gro -p $Project.top -ff $amber -water tip3p 2> grolog

which generate the .topology of the whole system (not solvent box yet).
•	ndx file: This file contains all the groups of the system (protein, waters, ions, etc.) and it is generated with: 

$gropath/gmx make_ndx -f $Project.gro -o $Project.ndx 

Any other group of atom numbers can be added to the $Project.ndx. Indeed, the group “GroupDyna” is added using the script “ndx-maker_mod.sh”. This “GroupDyna” group contains the atoms to be frozen during the MD. It is generated in function of what we want to freeze (see below). 
•	A Molecular Mechanics energy minimization is performed only on the side-chains and, in order to run it in the login node, it is ran in batches of 1000 energy minimization steps, otherwise it can be killed in some clusters.
Before running anything in gromacs, we need to generate the binary file “$Project.tpr”, which is generated by:

$gropath/gmx grompp -f standard-EM.mdp -c $Project.gro -n $Project.ndx -p $Project.top -o $Project.tpr

Here, the file “standard-EM.mdp” (/userapp/APEC_GOZEM/New_APEC/template/ standard-EM.mdp) contains information about how to run the gromacs minimization. More specifically, the freezegrps = GroupDyna, specify that the “GroupDyna” group is going to be frozen.
In this case “GroupDyna” contains all the atoms of the chromophore plus the atoms of the backbone.
•	The protein will be now embedded in a solvent box and the size of the box will be asked. The box is generated with:

$gropath/gmx editconf -f $Project.gro -bt cubic -box $box $box $box -o ${Project}_box_init.gro -c

And it is filled with pre-equilibrated water molecules provided by gromacs (spc216.gro) by:

$gropath/gmx solvate -cp ${Project}_box_init.gro -cs spc216.gro -o ${Project}_box_sol_init.gro -p $Project.top 

When the water molecules are added to the box, some molecules can be trapped in cavities of the protein which can causing problem during the Energy minimizations and MD. So, they will be removed, but one detail is that the water molecules added to fill the box are labeled as SOL, while the ones coming from dowser are HOH. This avoids the possibility of removing internal waters originally coming from the pdb. After this all the water molecules will be re-labelled as SOL.
These removed water molecules are removed from the .gro file, then a new .ndx file is generated and the topology file (.top) is updated with the new number of water molecules. This is performed in the lines between 260 and 350 of Solvent_box.sh.
•	A new Molecular Mechanic energy minimization is performed, this time relaxing everything but the Chromophore (protein and solvent molecules).
Therefore, a new “GroupDyna” has to be added to the .ndx file. But this time we need to have into account if the chromophore is FMN or FAD.
If it is FMN, all its atoms will be frozen, but if it is FAD, only the atoms labeled as QM, MM, LQ and LM in the initial “CHR_chain.xyz” will be frozen. The rest, which is the long tail of FAD will be energetically minimized.
The .tpr binary file (${Project}_box_sol.tpr) to run energy minimization is generated now, but before it will be used to add the ions to the system (see below). One detail here is that the file “min_sol.mdp” (/userapp/APEC_GOZEM/New_APEC/template/ASEC/min_sol.mdp) is the one now containing the instructions of how to run the gromacs minimization (PBC, Particle-Mesh Ewald electrostatics, frozen groups, etc.).
•	Adding the ions. The protocol already knows what the total charge of the system is, and it will add some ions to neutralize the global system. But it will also ask you if you want to add extra pairs of ions.
The way in which the ions are added, is randomly selecting a water molecule and replacing it by one ion. Therefore, there is a chance that an internal water kept by dowser were replaced by an ion, keeping inside a cavity. To avoid this, we make a loop in line 476 which ensures that the replaced water molecules are not any of the one kept by dowser.
At this point the user will be asked to double check that the SOL group has been selected to be replaced by the ions. If this is different, the Solvent_box.sh scrip has to be modified manually accordingly in line 511.
•	When the ions have been properly added with:

$gropath/gmx genion -seed $seed -s ${Project}_box_sol.tpr -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -nname CL -nq -1 -nn $charge -pname NA -pq 1 -np $pairs -o ${Project}_box_sol_ion.gro

the topology and ndx files are automatically updated but the “GroupDyna” needs to be added again then, the tpr binary has to be generated again.
Now the Energy minimization, relaxing everything but the chromophore, can be run in batches of 1000 steps in the login node.

Notes about Solvent_box.sh:
•	This script does not run properly in “photonmgt” due to a library issue. It must be run for the moment in GSU login node. I will fix this with suranga.  

5.	MD_NPT.sh (/userapp/APEC_GOZEM/New_APEC/template/ASEC/MD_NPT.sh): In the previous step we created a box around the protein and it was filled with water molecules. We agreed to do our MD using the NVT ensemble (constant Number of particles, Volume and Temperature) because it seems to be more convenient for APEC, but the volume of the box needs to be relaxed first. This is why this script is submitting a short NPT MD simulation. It will be asked about the temperature and other details (the script is self-explanatory about that). Details about the how to run the MD can be found in the dynamic_sol_NPT.mdp file (/userapp/APEC_GOZEM/New_APEC/template/ASEC/dynamic_sol_NPT.mdp).

6.	MD_NVT.sh (/userapp/APEC_GOZEM/New_APEC/template/ASEC/MD_NVT.sh): Once the NPT MD is done, the final .gro configurations (which contains the equilibrated volume defined at the end of the file) is used to stat the NVT MD. It will be asked some details and also if we want to parallelize the MD production, in which case, several seeds folders will be created in the Dynamics folder. Just to highlight that each seed will run the full thermalization steps and the production steps will be divided by the number of seeds.  The script is easy and self-explanatory. Details about the how to run the MD can be found in the dynamic_sol_NVT.mdp file

7.	MD_ASEC.sh (/userapp/APEC_GOZEM/New_APEC/template/ASEC/MD_ASEC.sh): This script will read the MD simulations and generate a bunch of files needed latter to generate the APEC configuration.
•	The long of the MD (thermalization, production …) ie read from dynamic_sol_NVT.mdp.
•	When the MD is done it stores the trajectories in the .xtc file (It also stores this information in the .trr along with something else, but we will read from the xtc). We are going to read 100 configurations from the production stages equally separated using:

$gropath/gmx trjconv -s ../Dynamic/seed_$i/output/${Project}_box_sol.tpr -f ../Dynamic/seed_$i/output/${Project}_box_sol.xtc -b $init -skip $skip -o Selected_100_seed_$i.gro

$init: is when the production of each seed start
$skip: is calculated as the size of the production devided by 100. It must be always larger than 1 ps (of 5 ps to be save) in order to ensure that the configurations are uncorrelated.
The 100 configurations are stored in the file “Selected_100.gro”. 
•	These 100 configurations will be used to generate the APEC configurations, but before that, the water molecules have to be ordered in the .gro file based on the distance from the Chromophore. It is done using:

$gropath/gmx trjorder -f Selected_100_seed_$i.gro -s ../Dynamic/seed_$i/output/${Project}_box_sol.tpr -n ../Dynamic/seed_$i/output/${Project}_box_sol.ndx -o Ordered_100_seed_$i.gro

The 100 ordered configurations will be storage in the file “Ordered_100.gro”. It will be explained next why we need to do this.
At this stage, you are asked which group to order with respect to (choose CHR) and which to order (choose Water).
•	For each of the 100 configurations we need to select a 22 A water shell, which will be used to generate the APEC configuration (this shell will comprise all the atoms of the protein, all the added ions and the water molecules found inside that shell). We have selected 22 A because the total amount of pseud-oatoms in the APEC configuration must be less than 1 000 000 (limited by molcas-tinker for the moment), so 22 A is more or less in that limit for iLOV.
But if we use a distance criterium to select the water molecules withing the shell for each of the configurations, we cannot warrantee that the total number of atoms will be the same on each shell. So, we select the first configurations from “Ordered_100.gro” and apply the distance criterium to generate the first shell. Then we count the total number of atoms comprised in this first shell and it is written in the “Infos.dat” file for the moment (update_infos.sh "Shell" "$shell" ../Infos.dat)
•	Templetes: Remember that the templates “template_gro2tk” and “template_tk2gro” generated before do not contain the Chromophore, the ions and the water molecules, so they will be added to the templates now.
The script is very well commented in this step, just keeo in mind that ir is ver important to keep the order of the blocks: Chromophore, then Water molecules and finally the ions.
•	MD_ASEC.f: This is very important program, unfortunately written in fortran :), which generate a bunch of very usefull files. 
First, look that “Selected_100_full.gro” will contain now the 100 cubic box configurations and the “Selected_100.gro” contains the 100 22 A shell configurations, generated from the Ordered_100.gro. 
Having all of this information and the templates “template_gro2tk” and “template_tk2gro”, MD_ASEC.f generates the following files:

ASEC_tk.xyz: It basically contains the xyz coordinates of the pseudo-atoms of 99 configurations in Tinker format. It is important to highlight that MD_ASEC.f computes the average position of each atom of the protein over the 100 configurations. Those average positions define an ideal average configuration of the protein, then the closest to the average real configuration is selected based on the rms deviation from the ideal one. So, what is stored in ASEC_tk.xyz are the 99 remaining configurations, this is excluding the closest to the average. This are the pseudo-atoms used in the final APEC configuration letter.

Best_Dynamic.xyz: It just shows the atoms that are relaxed during the MD in the closes to the average configuration (Tinker format). Just to note that MD_ASEC.f defines which atoms are relaxed during the MD because it checks what atoms change the coordinates from one configuration to the other. 

 Best_Config.gro: It shows the closest to the average configuration in gromacs format.

Dynamic.xyz: It contains the 100 configurations of the relaxed atoms. It is like a MD showing only the relaxed atoms (excluding the Chromophore)

list_tk.dat: This is the list of the atom numbers (from the Tinker format file) of the atoms relaxed during the MD.

Some of these files are just generated for visual inspection and others will be used next.

	Notes about MD_ASEC.sh:
		
•	Ignore “$dimer” for the moment, this is an incomplete and untested option started some time ago to consider dimers of proteins. $dimer is set as “No” in the Infos.dat file. 

•	Our Photon cluster saves the outputs of the dynamics in Dynamics/seed_?/output which is correct, but CDER saves in Dynamics/seed_?, not in the output folder, for some reason. So, if the dynamics ran in CDER, the xtc and the rest of the output files should be copied to output manually. 


8.	MD_2_QMMM.sh (/userapp/APEC_GOZEM/New_APEC/template/ASEC/MD_2_QMMM.sh):
We will convert the closest to the average configuration (Best_config.gro) in tinker format (with connectivities and the atom types). Note that we will not add the APEC pseudo-atoms yet.

First, the parametrization of the chromophore is defined as:

force=(["NC"]=1022 ["C"]=3 ["O"]=5 ["CA"]=115 ["CT"]=2 ["H"]=4 ["HC"]=14 ["Nstar"]=1017 ["H1"]=6 ["OH"]=63 ["HO"]=64 ["OS"]=1239 ["O2"]=1236 ["P"]=1235 ["CK"]=1021 ["NB"]=193 ["CB"]=149 ["N2"]=299 ["CQ"]=1023 ["H5"]=175)

It is basically the conversion from amber to Tinker format and it contain all the parameters needed both for FMN and FAD. The Tinker force field can be found here:
/userapp/APEC_GOZEM/New_APEC/template/amber99sb.prm.

There are two types of calculation in this script (procedure=1 or 2). Option 1 could be used in Step_0 to compute optimize the chromophore using a single configuration of the protein, NOT APEC. This option is deprecated. So, procedure=2 is what we are using, which is optimizing the chromophore from the beginning using APEC.

Procedure=2 proceeds in the following order:

•	Conversion of the Best_config.gro to Tinker format. Since Tinker do not recognize the chromophore it is removed from the gro file. Now the protein is converted from gro to pdb using gromacs ($gropath/gmx editconf …) and then from pdb to Tinker xyz using Tinker ($tinkerdir/pdbxyz …).
•	Using the coordinates of the chromophore from Best_config.gro file and the atom types from the original $chromophore.xyz (CHR_chain.xyz) the chromophore is added to the protein -tk.xyz file.
•	Adding connectivities. Now, the connectivities are added to the -tk.xyz file using a distance criterion tool from Tinker ($tinkerdir/xyzedit $Project-tk.xyz, option 7).
•	In Step_0 we start the QMMM optimizations by SCF opt. There are other options in that script like TS optimization which are inactive in the current version.
•	If we are not in Step_0, the same described steps are performed but the next script to run is now: Molcami_direct_CASSCF.sh  instead of Molcami_OptSCF.sh.


9.	Molcami_OptSCF.sh: (/userapp/APEC_GOZEM/New_APEC/template/ASEC/Molcami_OptSCF.sh)

It is time to generate the key file, which looks like this:

parameters amber99sb

QMMM 51
MM 8468
MM 8469
MM 8470
MM 8471
…
QM 8485
QM 8486
QM 8487
QM 8488
QM 8489
QM 8490
LA 8499
QMMM-microiteration ON
CHARGE  -8468   0.0000
CHARGE  -8469   -0.679065
CHARGE  -8470   0.191396
CHARGE  -8471   -0.789341
CHARGE  -8472   0.009456
CHARGE  -8473   -0.726673
CHARGE  -8474   0.321299
CHARGE  -8475   -0.674817
CHARGE  -8476   1.607913
CHARGE  -8477   -0.966389
CHARGE  -8478   -0.966389
CHARGE  -8479   -0.966389
CHARGE  -8491   0.040062
CHARGE  -8492   0.444657
CHARGE  -8493   0.034893
CHARGE  -8494   0.502721
CHARGE  -8495   0.100067
CHARGE  -8496   0.517943
CHARGE  -8497   -0.000672
CHARGE  -8498   -0.000672
ACTIVE 8468
ACTIVE 8469
ACTIVE 8470
ACTIVE 8471
ACTIVE 8472
…


In the previous step (MD_2_QMMM.sh) the file $Project-tk.xyz was created, including the chromophore in there. So, the key file will be created based on that -tk.xyz file. “MM” are the atoms of the chromophore tail that will be MM optimized during the QM/MM optimization (they are frozen during the MD).
“QM” are the atoms to be optimized quantum mechanically (also frozen during the MD). 
“LA” is the link atom.

There will be created two key files simultaneously, one that does not consider the link atom (${Project}_nolink.key) and another considering the link atom ($Project.key). The point is that ${Project}_nolink.key will be used by tinker to insert the link atom in the $Project-tk.xyz file. After that, $Project.key will be used in the QM/MM calculations.

The key file is generated in the following order:

•	In the original parametrization of the chromophore (CHR_chain.xyz) we have defined the QM/MM model. For example:

…
C2A      2.736   2.747 -17.700    CQ      XX
N3A      2.255   3.415 -16.615    NC      XX
C4B      1.267   2.666 -15.957    CB      XX
N        1.100   2.489  -1.125    NC      QM
C        1.691   3.595  -0.603    C       QM
…
N3       0.323   0.285  -0.902    N*      QM
C6       0.941   1.386  -0.331    CA      QM
C7      -0.086   0.365  -2.338    CT      LQ
C8      -1.482   0.867  -2.724    CT      LM
O2      -2.429   0.411  -1.754    OH      FX
C9      -1.791   0.363  -4.169    CT      FX
	…
Where the last column defines the QM/MM model. 
“XX” indicates MM atoms of the tail that are relaxed during the MD, they will be represented as APEC pseudo-atoms in the QM/MM optimization.
“FX” indicates MM atoms of the tail that are frozen during the MD. They are normally all the atoms defining the dihedrals after the link atom. Otherwise, these dihedral angles were not defined during the QM/MM optimization.
“LQ” and “LM” are the QM/MM frontier atoms. The link atom will be placed between them.

These are the QM/MM models implemented for FMN and FAD:

  

So, the first loop of this script runs over the number of atoms in the chromophore. Basically, it reads the atom number from -tk.xyz and it also read the last column of $chromophore.xyz (CHR_chain.xyz) to define if the atom will be MM of QM. In the case of MM atoms, we need to provide the charges, which are loaded from:
 /userapp/APEC_GOZEM/New_APEC/template/ASEC/charges_FMN
(charges_FAD is not implemented yet with Manchester, I plan to do it)  
This file only contains the charges of the MM, FX and XX atoms, which have been taken from Manchester force field parametrization (http://amber.manchester.ac.uk). Note that these charges are not exactly the same as in the rtp file used before for the MD (/userapp/APEC_GOZEM/New_APEC/template/ASEC/manchester_FMN_rtp). This is because the MM charges in the key file have to sum exactly -2, so the charge of LA has set to ZERO (to avoid over polarization) and some decimal places have been manually modifies to sum -2.
After this most of the key files has been generated.

•	Generate the link atom in the $Project-tk.xyz. Using the ${Project}_nolink.key we can insert the link atom using this from Tinker:

$tinkerdir/xyzedit $Project-tk.xyz   (Option 20)
•	reformat.f is just used to adjust some spaces in the new $Project-tk.xyz which already contains the LA.
•	Now we already have $Project-tk.xyz and $Project-tk.key, both considering the link atom.

10.	ASEC.sh (/userapp/APEC_GOZEM/New_APEC/template/ASEC/ASEC.sh)

So far, we did not add the APEC pseudo-atoms to the -tk.xyz nor to the forcer field. So, this is what will be done now. Remember that the file ASEC_tk.xyz generated before by MD_ASEC.f contains the other 99 overlapped configurations (excluding the closest to the average configuration, which has been converted to -tk.xyz) in Tinker format of the relaxed atoms during the MD. The beauty of MD_ASEC.f is that it does not care about FX, XX MM …, it just considers a moving atom because it charges its coordinated among the 100 configurations.

The idea is to add the ASEC_tk.xyz to the xyz file and also add the scaled atom types, both to the xyz file and to the force field amber99sb.ff. This is done with the fortran codes ASEC.f and New_parameters.f:

ASEC.f: It generates the final xyz coordinates (new_coordinates_tk.xyz). Containing the Closest to the average configuration at the beginning, followed by the APEC pseudo-atoms of the other 99 configurations. Comments in that code are very helpful.

•	It starts by reading from list_tk.dat which contains the list of atoms that are relaxed during the MD. This is added to the imov array variable. 

•	It is defined the “newindx2” variable. What is this index? If we look at the original amber99sb.prm (/userapp/APEC_GOZEM/New_APEC/template/amber99sb.prm) tinker force field, we can see the that the larger atom type is 2012 (excluding 2999 reserved for the LA). So, we have decided that the scaled amber parameters of the APEC pseudo-atoms will start at newindx2=2101. This have to be the same for New_parameters.f.

•	The “iused2” array variable is used to not generate new atom types already used for other atoms. 

•	Then a loop is performed first over all the atoms of the first configuration (the closest to the average that was converted to _tk.xyz)). If the atoms is present in the imov array, it means that it will be an APEC pseudo-atom. Then its coordinates are read from coordinates_tk.xyz and it is added a new atom type (newindx2). If the atoms are FX atom, which are the frozen atoms in FAD to properly define the dihedral angles, they will have atom type indexes starting at 4001, because these atoms are not APEC pseudo-atoms.

•	The APEC pseudo-atoms will be analyzed now. There is a chance that two pseudo-atoms have exactly the same coordinates. This is ok, but if those atoms are within the 4 A cavity of the Chromophore, we will have an issue with SPAPAF, because it uses the 4 A cavity to compute to compute the model Hessian.

So, there are a set of loops devoted to find pseudo-atoms with the same coordinates and if found it add 0.002 to one of the coordinates. These set of loops are not very efficient and sometimes it fails.

•	Finnaly, the APEC pseudo-atoms are added to the final xyz file, adding also the atom types previously defined for the first configuration. It can be done because ASEC_tk.xyz was created in the way that the first 99 pseudo-atoms correspond to the first atom of the closest to the average configuration and so on.

New_parameters.f: It will add all the new APEC atom types to the force field (amber99sb.prm) scaling the charges and the vdw parameters.

•	This program basically read all the parameters from the original amber99sb.prm force field (charges and vdw) and generate the new atom types starting at 2101 as in the xyz file. 
•	Each of this new atom type will have 1/100 of the charge.
•	In the case of the van der Waals parameters, we can see that there are originally 50 vdw parameters in the amber99sb.prm. So the new vdw parameters will be the same number as before plus 100 and they will have associated the same sigma but a fraction of the epsilon (1/10000).
•	All of this is added together into the amber99sb.prm and we have everything that we need to start the QM/MM calculations (key file, xyz and parameters). The Opt SCF input file was previously loaded by Molcami_OptSCF.sh from the template “/userapp/APEC_GOZEM/New_APEC/template/ASEC/template_OptSCF” and it is submitted.

11.	The next scripts: Molcami2_mod.sh,  1st_to_2nd_mod.sh, 2nd_to_3rd_mod.sh, sp_to_opt_VDZP_mod.sh (/userapp/APEC_GOZEM/New_APEC/template/ASEC) are very easy to read because they just read the results from the previous calculations and improves the level of calculation.
What we have stablished so far for Step_0 is:

•	SCF Opt/ANO-L-VDZ
•	CASSCF SP(16,14)/ANO-L-VDZ
•	CASSCF Opt(16,14)/ANO-L-VDZ
•	CASSCF SP(16,14)/ANO-L-VDZP
•	CASSCF Opt(16,14)/ANO-L-VDZP

For the next steps we just do CASSCF Opt(16,14)/ANO-L-VDZP, loading the JobIph from the previous step CASSCF Opt(16,14)/ANO-L-VDZP.

In Step_0 we do not compute CASPT2 energies because the environment has not been adapted yet to the optimized structure and charges.

12.	finalPDB_mod.sh (/userapp/APEC_GOZEM/New_APEC/template/ASEC/finalPDB_mod.sh): Once we are done with the CASSCF Opt(16,14)/ANO-L-VDZP, this script inserts the optimized structure of the chromophore during the QM/MM optimization into the closest to the average configuration (Best_conf.gro) to start the next MD from that configuration. It also converts that structure to pdb in case we need it.

13.	fitting_ESPF.sh (/userapp/APEC_GOZEM/New_APEC/template/ASEC/fitting_ESPF.sh): This script reads the ESPF charges of the electronic state that we are optimizing from the CASSCF Opt(16,14)/ANO-L-VDZP output file and generate a new_rtp file for the chromophore which will be inserted into the aminoacids.rtp bu the next script (Next_Iteration.sh) to run the MD of the next step.  

14.	Next_Iteration.sh (/userapp/APEC_GOZEM/New_APEC/template/ASEC/Next_Iteration.sh): This script collects all the needed information to start a new Step. There are many things that do not need to be done again, so it goes straight to the MD_NVT.sh script to run the MD. As previously stated it update the charges of the chromophore by updating the new_rtp of the chromophore into the aminoacids.rtp.

15.	Steps to optimize excite states: This step is not automatic, and the transition to start with the iteration in the excited state needs to be done manually. 
•	Once we are done with Step_0, it means fully optimized at CASSCF Opt(16,14)/ANO-L-VDZP level, we need to optimize the desired excited state here in Step_0. 
•	Then we copy this Step_0 to another location and switch “Electronic_state 1” to “Electronic_state 2” in the Infos.dat file. Then we can continue with the finalPDB_mod.sh script.
•	It is important to do it in that way (I mean, starting from Step_0 of the ground state) because the exited state calculations must have the same number of atoms during the MD and in the QM/MM shell to be comparable.

16.	Steps to compute the Total QMMM energy. This set of scripts are bought automatically by the protocol for the moment. But if we need to compute the adiabatic transitions, then we need to compute the average MM potential energy. To do this we follow these steps:
•	Decide in what Step we want to compute the average MM energy. Let sat we want to use the CASPT2 energies from Step_3, then we need the corresponding average MM energy.
Copy the script /userapp/APEC_GOZEM/New_APEC/template/ASEC/Total_QMMM_Energy_MD.sh to Step_3.
This script will run a long enough MD, saving enough configurations to compute a converged average MM potential energy. 

 

From the graphic above we would need about 20 000 uncorrelated configurations to get a converged MM potential energy. So, this script is submitting a 250 000 ps MD (production) saving configurations every 5 ps, which should be more than enough to a get a converged value.
This script will create a new folder beside Step_3, name Step_3_Total_QMMM, Containing the calculations folder, the MD and some other information.


•	The script  /userapp/APEC_GOZEM/New_APEC/template/ASEC/Total_QMMM_Energy_rerun.sh will be copied automatically to Step_3_Total_QMMM/calculations folder. This script will set to ZERO all the parameters of the chromophore (charges and vdw) and make a re-run of the previous MD. This is basically to recompute the energies of each storages configuration without considering any interaction with the chromophore. In other words, it is the MM energy of the protein.

•	Total_QMMM_Energy_results.sh: This is the last script, which basically collects the MM energies from the md.log files and compute the average MM potential energy. It also put together all the values (CASPT2, MM …) in the file Step_3_Total_QMMM/calculations/Total_QMMM_Energy/ Total_QMMM_Energy.dat





  

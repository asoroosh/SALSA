#bin/bash


NCORES=2
NRLZ=500
T=200

COHORT=ROCKLAND

#METHODLIST=(ACF AR-YW AR-W ARMAHR)
METHODLIST=(ACF)
ARMODE=(1 2 5 10 20)
ACMODE=(5 10 15 $(echo "sqrt($T)" | bc) $(echo "2*sqrt($T)" | bc))

FWHMsize=0

STRGDIR=/well/nichols/users/scf915
COHORTDIR=${STRGDIR}/${COHORT}

Path2ImgRaw=${STRGDIR}/${COHORT}/raw

############################################
TRs=$(cat ${Path2ImgRaw}/task-rest_acq-645_bold.json | grep RepetitionTime | awk {'print $2'} | awk -F"," '{print $1}')

TR=$(echo $TRs*1000 | bc | awk -F'.' {'print $1'})
SesID=DS2
SubID=A00028185

############################################

SUBMITDIR=/users/nichols/scf915/bin/FILM2/NullSynfMRI/SIM_${COHORT}_${T}_${TR}_Submitters
mkdir -p ${SUBMITDIR}

for METH_ID in ${METHODLIST[@]}
do
	echo ${METH_ID}

	MAO=0; ARMODE0=${ARMODE[@]}
	[ $METH_ID == "ARMAHR" ]&& MAO=1
	[ $METH_ID == "ACF" ]&& ARMODE0=${ACMODE[@]}

	for ARO in ${ARMODE0[@]}
	do

		JobName=SIM_${COHORT}_${T}_${TR}_${METH_ID}_AR-${ARO}_MA-${MAO}_FWHM${FWHMsize}
		SubmitterFileName="${SUBMITDIR}/SubmitMe_${JobName}.sh"

		echo ${SubmitterFileName}

		Path2ImgResults=${COHORTDIR}/R.SIM/${JobName}
		OpLog=${Path2ImgResults}/logs

		mkdir -p ${OpLog}

############################################
############################################
cat > $SubmitterFileName << EOF
#!/bin/bash
#$ -cwd
#$ -q short.qe
#$ -pe shmem ${NCORES}
#$ -o ${OpLog}/${JobName}_\\\$JOB_ID_\\\$TASK_ID.out
#$ -e ${OpLog}/${JobName}_\\\$JOB_ID_\\\$TASK_ID.err
#$ -N ${JobName}
#$ -t 1-${NRLZ}

# #$ -q short.qc@@short.hge


set -e

export OMP_NUM_THREADS=${NCORES}

STATFILE=${OpLog}/${JobName}_\${JOB_ID}_\${SGE_TASK_ID}.stat

# The stat file
echo 0 > \$STATFILE

# This whole business is rubbish! This should be fixed!
# source \${HOME}/.bashrc
# module use -a /apps/eb/skylake/modules/all
module load Octave/4.4.1-foss-2018b

#SubID=\$(cat ${COHORTDIR}/sub.txt | sed "\${SGE_TASK_ID}q;d" )
#SubID=\$(echo \${SubID} | awk -F"-" '{print \$2}')

SIDX=\${SGE_TASK_ID}

OCTSCRPT=\${HOME}/bin/FILM2/NullSynfMRI
cd \${OCTSCRPT}
octave -q --eval "COHORTDIR=\"${COHORTDIR}\"; Path2ImgResults=\"${Path2ImgResults}\"; pwdmethod=\"${METH_ID}\"; lFWHM=${FWHMsize}; TR=${TRs}; Mord=${ARO}; MPparamNum=${MAO}; SIDX=\${SIDX}; SubID=\"${SubID}\"; SesID=\"${SesID}\"; T=${T}; Gen_SynImg_bmrc; quit"

# The stat file
echo 1 > \$STATFILE

EOF
############################################
############################################
	done
done

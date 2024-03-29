#bin/bash

NCORES=2
COHORT=ROCKLAND

ACQLAB=CAP
T=120 #
TRs=2.5 # in second

TR=$(echo $TRs*1000 | bc | awk -F'.' {'print $1'})

METHODLIST=(ACF ACFadj AR-W ARMAHR)
ARMODE=(1 2 5 10 20)
ACMODE=(5 $(echo "sqrt($T)" | bc) 15 $(echo "2*sqrt($T)" | bc))

FWHMsize=0
TempTreMethod="dct"

STRGDIR=/well/nichols/users/scf915
COHORTDIR=${STRGDIR}/${COHORT}

Path2ImgRaw=${STRGDIR}/${COHORT}/raw

############################################
#TR=$(cat ${Path2ImgRaw}/task-rest_acq-645_bold.json | grep RepetitionTime | awk {'print $2'} | awk -F"," '{print $1}')
SesID=DS2
NUMJB=$(cat ${COHORTDIR}/sub.txt | wc -l )
############################################

SUBMITDIR=/users/nichols/scf915/bin/FILM2/NullRealfMRI/Img/${COHORT}_${T}_${TR}_Submitters
mkdir -p ${SUBMITDIR}

for METH_ID in ${METHODLIST[@]}
do
	echo ${METH_ID}

	MAO=0; ARMODE0=${ARMODE[@]}
	[ $METH_ID == "ARMAHR" ]&& MAO=1
	if [ $METH_ID == "ACF" ] || [ $METH_ID == "ACFadj" ]; then
		ARMODE0=${ACMODE[@]}
	fi

	for ARO in ${ARMODE0[@]}
	do

		JobName=${COHORT}_${TR}_${T}_${METH_ID}_AR-${ARO}_MA-${MAO}_FWHM${FWHMsize}_${TempTreMethod}
		SubmitterFileName="${SUBMITDIR}/SubmitMe_${JobName}.sh"

		echo ${SubmitterFileName}

		Path2ImgResults=${COHORTDIR}/R.PW/${JobName}
		OpLog=${Path2ImgResults}/logs

		mkdir -p ${OpLog}

############################################
############################################
cat > $SubmitterFileName << EOF
#!/bin/bash
#$ -cwd
#$ -q short.qc@@short.hge
#$ -pe shmem ${NCORES}
#$ -o ${OpLog}/${JobName}_\\\$JOB_ID_\\\$TASK_ID.out
#$ -e ${OpLog}/${JobName}_\\\$JOB_ID_\\\$TASK_ID.err
#$ -N ${JobName}
#$ -t 1-51 #${NUMJB}

export OMP_NUM_THREADS=${NCORES}

STATFILE=${OpLog}/${JobName}_\${JOB_ID}_\${SGE_TASK_ID}.stat

# The stat file
echo 0 > \$STATFILE

# This whole business is rubbish! This should be fixed!
# source \${HOME}/.bashrc
# module use -a /apps/eb/skylake/modules/all
module load Octave/4.4.1-foss-2018b

#SubID=\$(cat ${COHORTDIR}/sub.txt | sed "\${SGE_TASK_ID}q;d" )
SubID=\$(cat ${COHORTDIR}/participants.tsv | awk {'print \$1'} | sed "\${SGE_TASK_ID}q;d")
#SubID=\$(echo \${SubID} | awk -F"-" '{print \$2}')

OCTSCRPT=\${HOME}/bin/FILM2/NullRealfMRI/Img
cd \${OCTSCRPT}
octave -q --eval "COHORTDIR=\"${COHORTDIR}\"; Path2ImgResults=\"${Path2ImgResults}\"; pwdmethod=\"${METH_ID}\"; lFWHM=${FWHMsize}; ACQLAB=\"${ACQLAB}\"; TR=${TRs}; Mord=${ARO}; MPparamNum=${MAO}; TempTreMethod=\"${TempTreMethod}\"; SubID=\"\${SubID}\"; SesID=\"${SesID}\"; NullSim_Img_bmrc_cap; quit"

# The stat file
echo 1 > \$STATFILE

EOF
############################################
############################################
	done
done

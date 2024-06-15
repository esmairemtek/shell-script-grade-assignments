#!/bin/bash

# Checks if the arguments are in the correct format
CheckArguments() {
	maxGrade=$1
	expectedOutput=$2
	submissionsFolder=$3
	
	echo "Checking the arguments..."
	# checks if the first argument is valid
	if ! [ $maxGrade -gt 0 ]; then
		echo "Error: Maximum point is not a positive integer!"
		return 1
	fi

	# checks if the second argument is valid 
	if ! [ -f $expectedOutput ]; then
		echo "Error: Correct output file does not exist!"
		return 1
	fi

	# checks if the third argument is valid
	if ! [ -d $submissionsFolder ]; then # submissions folder doesn't exist 
		echo "Error: Submissions folder does not exist!"
		return 1
	else # submissions folder exists
		if [ "$(ls -A $submissionsFolder | wc -l)" -eq 0 ]; then # submissions folder is empty
			echo "Error: Submissions folder is empty!"
			return 1
		else # submissions folder is not empty
			return 0
		fi
	fi
}

# Checks if the submitted file has a name in the correct format.
CheckFileName() {
	fileName=$1
	case "$fileName" in 
	(322_h1_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].sh) return 0 ;;
	(*)	echo "Incorrect file name format: $fileName"
		echo "Incorrect file name format: $fileName" >> grading/log.txt
		return 1 ;;
	esac
}

# Checks if the user have right to execute, and if not, gives it.
CheckExecuteRight() {
	fileName="submissions/$1"
	echo "Checking file permission..."
	if ! [ -x "$fileName" ]; then
		chmod +x "$fileName"
		if [ -x "$fileName" ]; then
			echo "Changed permission of $fileName to executable."
		fi
	fi
}

# Executes the script by taking its output to out.txt, and assigns grade 0 if timeout occurs
# Returns 1 if timeout occurs, returns 0 if no timeout occurs.
ExecuteScript() {
	fileName="submissions/$1"
	studentID=$2
	correctOutput=$3
	
	timeout 1m ./$fileName > grading/out.txt

	if [ $? -eq 124 ]; then
		echo "Timeout has occured."
		echo "$studentID: Too long execution." >> grading/log.txt
		AssignGrade 0 $studentID
		return 1
	fi
	return 0
}

# Assigns the given grade and moves out the out.txt as 322_h1_x_out.txt
AssignGrade() {
	grade=$1
	studentID=$2
	newOutFileName="322_h1_${studentID}_out.txt"
	
	mv grading/out.txt grading/$newOutFileName
	echo "$2: $1" >> grading/result.txt
}

# Checks if the contents of out.txt matches with correct output and calculates grade
# Returns the calculated grade
CheckContentAndCalculateGrade() {
	
	outputFile=grading/out.txt
	expectedOutput=$1
	maxGrade=$2
	
	size1=$(wc -l < $outputFile)
	size2=$(wc -l < $expectedOutput)
	maxSize=$(( size1 > size2 ? size1 : size2))
	numberOfDifferentLines=0
	
	for((i=1; i<=$maxSize; i++)); do
		line1=$(sed "${i}q;d" "$outputFile")
		line2=$(sed "${i}q;d" "$expectedOutput")
		
		if [[ $line1 != $line2 ]]; then
			numberOfDifferentLines=$((numberOfDifferentLines+1))
		fi
	done

	grade=$(($maxGrade-$numberOfDifferentLines))
	return $grade
}
 
### Starts running here ###
echo "Creating grading file..."	
mkdir grading
touch grading/log.txt
touch grading/result.txt

maxGrade=$1
expectedOutput=$2
submissionsFolder=$3

CheckArguments $maxGrade $expectedOutput $submissionsFolder

if [ $? == 0 ]; then
# arguments are in the correct format, start checking submissions
	echo "$(ls $submissionsFolder | wc -l) students submitted homework."
	
	for file in $(ls $submissionsFolder); do 
	# starting of the things that will be done for each submission file
		echo "Grading process for "$file" is started."
		CheckFileName $file		
		if [ $? == 0 ]; then 
		# file name is in correct format, keep evalualting
			CheckExecuteRight "$file"
			
			# extract student ID from submission file
			studentID="${file#*_}"; studentID="${studentID#*_}"; studentID="${studentID%%.*}";
			echo "Student ID is: $studentID" 
			
			ExecuteScript $file $studentID $expectedOutput $maxGrade
				
			if [ $? == 0 ]; then 
			# no timeout occured, calculate grade
				CheckContentAndCalculateGrade $expectedOutput $maxGrade
				AssignGrade $? $studentID
			fi
		fi
	done
else 
	exit 1
fi

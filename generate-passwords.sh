#!/bin/bash -eu

###
# Generates a file with all passwords
###

rm -f ~/passwords.sh

tokens=($password_keys)
for token in "${tokens[@]}"
do
	pwd=`pwgen 16 1`
	echo "export $token=$pwd" >> ~/passwords.sh
done;

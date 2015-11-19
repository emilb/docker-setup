source ../passwords.sh

tokens=($users)
for user in "${tokens[@]}"
do
	pwd=`printenv $user`
	sudo adduser $user --gecos "$user,,," --disabled-password
	echo $user:$pwd | chpasswd
done

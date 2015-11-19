
tokens=($users)
for user in "${tokens[@]}"
do
	pwd=`printenv $user`
	sudo adduser $user --gecos "$user,,," --disabled-password
	echo $user:$pwd | chpasswd
done

sudo usermod -aG docker emil
sudo usermod -aG docker patrik
sudo usermod -aG docker admin

#/bin/bash

git add *
git commit -m "ueincn"
git push

if [ $? == "0" ]; then
	echo "Git Push Complete!"
else
	echo "Git Push Fail!"
fi

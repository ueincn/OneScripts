#/bin/bash

git add *
git commit -m "ueincn"
git push

echo ""
echo "=========================="
if [ $? == "0" ]; then
	echo "Git Push Complete!"
else
	echo "Git Push Fail!"
fi

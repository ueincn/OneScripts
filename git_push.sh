#/bin/bash

git add *
echo ""

git commit -m "ueincn"
echo ""

git push

echo ""
echo "=========================="
if [ $? == "0" ]; then
	echo "Git Push ... Complete!"
else
	echo "Git Push ... Fail!"
fi

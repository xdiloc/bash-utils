#!/bin/bash
echo 'Hello '$(whoami);
echo 'plese enter sudo password...';
sudo sleep 1
#=============================================
echo "\n=== cache deb ===";
echo "\nContinue clear (y/n)?";
read CONT
if [ "$CONT" = "y" ]; then

echo '\nplese enter sudo password...';
sudo sleep 1
sudo apt-get autoclean
sudo apt-get autoremove
sudo apt-get clean

fi
#=============================================
#echo "\n=== old kernel ===";
#echo 'latest: '$(uname -r)'\n';

#echo 'old: ';
#sudo dpkg -l linux-{image,headers,hwe,modules}-* | awk '/^ii/{print $2}' | egrep '[0-9]+\.[0-9]+\.[0-9]+' | grep -v $(uname -r | cut -d- -f-2)

#echo "\nContinue clear (y/n)?";
#read CONT
#if [ "$CONT" = "y" ]; then

#echo '\nplese enter sudo password...';
#sudo sleep 1
#sudo dpkg -l linux-{image,headers,hwe,modules}-* | awk '/^ii/{print $2}' | egrep '[0-9]+\.[0-9]+\.[0-9]+' | grep -v $(uname -r | cut -d- -f-2) | xargs sudo dpkg --purge

#fi
#=============================================
echo "\n=== log list ===";

cd '/home/'$(whoami)'/';
echo '\nscan /home/'$(whoami)'/';
find -maxdepth 1 -name '.xsession-errors'
find -maxdepth 1 -name '.xsession-errors.old'

cd "/var/log/";
echo "\nscan /var/log/";
sudo find -name '*.0'
sudo find -name '*.1'
sudo find -name '*.gz'
sudo find -name '*.log'
sudo find -name '*.old'
sudo find -name '*.txt'
sudo find -name '*.journal'
sudo find -name '*.journal~'

echo "\nContinue clear (y/n)?";
read CONT
if [ "$CONT" = "y" ]; then

cd '/home/'$(whoami)'/';
echo '\nclear /home/'$(whoami)'/';
find -maxdepth 1 -name '.xsession-errors' -delete
find -maxdepth 1 -name '.xsession-errors.old' -delete

cd "/var/log/";
echo "\nclear /var/log/";
echo '\nplese enter sudo password...';
sudo sleep 1
sudo find -name '*.0' -delete
sudo find -name '*.1' -delete
sudo find -name '*.gz' -delete
sudo find -name '*.log' -delete
sudo find -name '*.old' -delete
sudo find -name '*.txt' -delete
sudo find -name '*.journal' -delete
sudo find -name '*.journal~' -delete

fi
#=============================================
echo "\n=== cache list ===";

cd '/home/'$(whoami)'/.cache/';
echo '\nscan /home/'$(whoami)'/.cache/';
find -name '*'

echo "\nContinue clear (y/n)?";
read CONT
if [ "$CONT" = "y" ]; then

cd '/home/'$(whoami)'/.cache/';
echo '\nclear /home/'$(whoami)'/.cache/';
find -name '*' -delete

fi

#=============================================
echo "\n=== root history ===";
echo "/root/.history";
echo "/root/.bash_history";

echo "\nContinue clear (y/n)?";
read CONT
if [ "$CONT" = "y" ]; then
sudo rm -f /root/.history /root/.bash_history

fi
#=============================================
sudo -k
echo "\n=== Cleared ===";
echo "Press any key to continue..."
read -n 1 -s

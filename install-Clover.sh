#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'

clear

echo Clover Install Script by ryanrudolf
echo https://github.com/ryanrudolfoba/SteamDeck-Clover-dualboot
sleep 2

# Password sanity check - make sure sudo password is already set by end user!

if [ "$(passwd --status deck | tr -s " " | cut -d " " -f 2)" == "P" ]
then
	read -s -p "Please enter current sudo password: " current_password ; echo
	echo Checking if the sudo password is correct.
	echo -e "$current_password\n" | sudo -S -k ls &> /dev/null

	if [ $? -eq 0 ]

	then
		echo -e "$GREEN"Sudo password is good!
	else
		echo -e "$RED"Sudo password is wrong! Re-run the script and make sure to enter the correct sudo password!
		exit
	fi

else
	echo -e "$RED"Sudo password is blank! Setup a sudo password first and then re-run script!
	passwd
	exit
fi

# sudo password is already set by the end user, all good let's go!
echo -e "$current_password\n" | sudo -S ls &> /dev/null
if [ $? -eq 0 ]
then
	echo -e "$GREEN"1st sanity check. So far so good!
else
	echo -e "$RED"Something went wrong on the 1st sanity check! Re-run script!
	exit
fi

# mount Clover ISO
sudo mkdir ~/temp-clover && sudo mount Clover-5151-X64.iso ~/temp-clover &> /dev/null
if [ $? -eq 0 ]
then
	echo -e "$GREEN"2nd sanity check. ISO has been mounted!
else
	echo -e "$RED"Error mounting ISO!
	sudo umount ~/temp-clover
	rmdir ~/temp-clover
	exit
fi

# copy Clover files to EFI system partition
sudo mkdir -p /esp/efi/clover && sudo cp -Rf ~/temp-clover/efi/clover /esp/efi/ && sudo cp custom/config.plist /esp/efi/clover && sudo cp -Rf custom/themes/* /esp/efi/clover/themes

if [ $? -eq 0 ]
then
	echo -e "$GREEN"3rd sanity check. Clover has been copied to the EFI system partition!
else
	echo -e "$RED"Error copying files. Something went wrong.
	sudo umount ~/temp-clover
	rmdir ~/temp-clover
	exit
fi

# cleanup temp directories created
sudo umount ~/temp-clover
sudo rmdir ~/temp-clover

# remove previous Clover entries before re-creating them
for entry in $(efibootmgr | grep -i "Clover" | colrm 9 | colrm 1 4)
do
	sudo efibootmgr -b $entry -B &> /dev/null
done

# Sanity check - is SteamOS EFI entry exists?
efibootmgr | grep "Steam" &> /dev/null

if [ $? -eq 0 ]
then
	echo -e "$GREEN"4th sanity check. SteamOS EFI entry is good, no action needed!
else
	echo -e "$RED"4th sanity check. SteamOS EFI entry does not exist! Re-creating SteamOS EFI entry.
	sudo efibootmgr -c -d /dev/nvme0n1 -p 1 -L "SteamOS" -l "\EFI\steamos\steamcl.efi" &> /dev/null
fi

# install Clover to the EFI system partition
sudo efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Clover - GUI Boot Manager" -l "\EFI\clover\cloverx64.efi" &> /dev/null

# make Clover the next boot option!
Clover=$(efibootmgr |  grep -i Clover | colrm 9 | colrm 1 4)
sudo efibootmgr -n $Clover &> /dev/null

# copy Windows scripts to the Windows partition
Windows=$(sudo blkid | grep "Basic data partition" | grep 'nvme.*ntfs.*Basic data partition' | cut -d ":" -f 1 | head -n1)
mkdir ~/windows-temp
sudo mount $Windows ~/windows-temp &> /dev/null

if [ $? -eq 0 ]
then
	echo -e "$GREEN"5th sanity check. Windows C drive successfully mounted! Copying scripts to the C drive.
	sudo rm -rf ~/windows-temp/1Clover-tools || sudo mkdir -p ~/windows-temp/1Clover-tools
	sudo cp -R CloverWindows ~/windows-temp/1Clover-tools
	sync ; sleep 5
else
	echo -e "$RED"5th sanity check. Error mounting the Windows C drive!
	echo -e "$RED"Please manually download the zip file from the github when doing the Windows install!
fi

sudo umount ~/windows-temp &> /dev/null
rmdir ~/windows-temp

# Final sanity check
efibootmgr | grep "Clover - GUI" &> /dev/null

if [ $? -eq 0 ]
then
	echo -e "$GREEN"Final sanity check. Clover has been successfully installed to the EFI system partition!
else
	echo -e "$RED"Whoopsie something went wrong. Clover is not installed.
	exit
fi

# copy dolphin root extension to easily add themes
mkdir -p ~/.local/share/kservices5/ServiceMenus
cp custom/open_as_root.desktop ~/.local/share/kservices5/ServiceMenus

sleep 2
echo \****************************************************************************************************
echo Post install scripts saved in 1Clover-tools. Use them as needed -
echo \****************************************************************************************************
echo enable-windows-efi.sh   -   Use this script to re-enable Windows EFI entry and temp disable Clover.
echo uninstall-Clover.sh     -   Use this to completely uninstall Clover from the EFI system partition.
echo \****************************************************************************************************
echo \****************************************************************************************************

#################################################################################
################################ post install ###################################
#################################################################################

# create ~/1Clover-tools and place the scripts in there
mkdir  ~/1Clover-tools &> /dev/null
rm ~/1Clover-tools/* &> /dev/null

# enable-windows-efi.sh
cat > ~/1Clover-tools/enable-windows-efi.sh << EOF
#!/bin/bash

# make Windows the next boot option!
Windows=\$(efibootmgr | grep -i Windows | colrm 9 | colrm 1 4)
sudo efibootmgr -n \$Windows &> /dev/null
echo Clover has been deactivated and Windows EFI entry has been re-enabled!
EOF

# uninstall-Clover.sh
cat > ~/1Clover-tools/uninstall-Clover.sh << EOF
#!/bin/bash

# remove Clover from the EFI system partition
sudo rm -rf /esp/efi/clover

for entry in \$(efibootmgr | grep "Clover - GUI" | colrm 9 | colrm 1 4)
do
	sudo efibootmgr -b \$entry -B &> /dev/null
done

grep -v 1Clover-tools ~/.bash_profile > ~/.bash_profile.temp
mv ~/.bash_profile.temp ~/.bash_profile

rm -rf ~/1Clover-tools/*

# make Windows the next boot option!
Windows=\$(efibootmgr | grep -i Windows | colrm 9 | colrm 1 4)
sudo efibootmgr -n \$Windows &> /dev/null

# delete dolphin root extension
rm ~/.local/share/kservices5/ServiceMenus/open_as_root.desktop
echo Clover has been uninstalled and the Windows EFI entry has been restored!
EOF

# post-install-Clover.sh
cat > ~/1Clover-tools/post-install-Clover.sh << EOF
#!/bin/bash
echo -e "$current_password\n" | sudo -S ls &> /dev/null

date  > ~/1Clover-tools/status.txt

echo BIOS Version : \$(sudo dmidecode -s bios-version) >> ~/1Clover-tools/status.txt

# check for dump files
dumpfiles=\$(ls -l /sys/firmware/efi/efivars/dump-type* 2> /dev/null | wc -l)

if [ \$dumpfiles -gt 0 ]
then
	echo dump files exists. performing cleanup. >> \$CloverStatus
	sudo rm -f /sys/firmware/efi/efivars/dump-type*
else
	echo no dump files. no action needed. >> \$CloverStatus
fi

# Sanity Check - are the needed EFI entries available?

efibootmgr | grep -i Clover &> /dev/null
if [ \$? -eq 0 ]
then
	echo Clover EFI entry exists! No need to re-add Clover. >> ~/1Clover-tools/status.txt
else
	echo Clover EFI entry is not found. Need to re-ad Clover. >> ~/1Clover-tools/status.txt
	sudo efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Clover - GUI Boot Manager" -l "\EFI\clover\cloverx64.efi" &> /dev/null
fi

efibootmgr | grep -i Steam &> /dev/null
if [ \$? -eq 0 ]
then
	echo SteamOS EFI entry exists! No need to re-add SteamOS. >> ~/1Clover-tools/status.txt
else
	echo SteamOS EFI entry is not found. Need to re-add SteamOS. >> ~/1Clover-tools/status.txt
	sudo efibootmgr -c -d /dev/nvme0n1 -p 1 -L "SteamOS" -l "\EFI\steamos\steamcl.efi" &> /dev/null
fi

# make Clover the next boot option!
Clover=\$(efibootmgr | grep -i Clover | colrm 9 | colrm 1 4)
sudo efibootmgr -n \$Clover &> /dev/null

echo "*** Current state of EFI entries ****" >> ~/1Clover-tools/status.txt
efibootmgr >> ~/1Clover-tools/status.txt
EOF

grep 1Clover-tools ~/.bash_profile &> /dev/null
if [ $? -eq 0 ]
then
	echo -e "$GREEN"Post install script already present no action needed! Clover install is done!
else
	echo -e "$RED"Post install script not found! Adding post install script!
	echo "~/1Clover-tools/post-install-Clover.sh" >> ~/.bash_profile
	echo -e "$GREEN"Post install script added! Clover install is done!
fi

chmod +x ~/1Clover-tools/*

#!/bin/bash
echo "https://medium.com/@farazfazli/how-i-reverse-engineered-keis-and-sidesync-and-fixed-mtp-8949acbb1c29"
echo "sudo kextutil -b com.devguru.driver.SamsungComposite -v 5"
echo "start"
echo "kextstat | grep -v com.apple"
sudo kextstat | grep -v com.apple
echo "kextfind -s -b com.devguru"
sudo kextfind -s -b com.devguru
echo "kextunload -m {bundleId}"
sudo kextunload -m com.devguru.driver.SamsungComposite -v 5
sudo kextunload -m com.devguru.driver.SamsungMTP -v 5
sudo kextunload -m com.devguru.driver.SamsungACMControl -v 5
sudo kextunload -m com.devguru.driver.SamsungACMData -v 5
sudo kextunload -b /System/Library/Extentions/ssuddrv.kext -v 5
sudo kextunload -b /Library/Extentions/ssuddrv.kext -v 5
echo "remove kext"
sudo rm -rf /Library/Extentions/ssuddrv.kext
echo "kextstat | grep -v com.apple"
kextstat | grep -v com.apple
#!/bin/bash

#Grenfell startup script

#///////////////////////////////////
#Funksjoner
#/////////////////////////////////





#////////////////////////
#Menyvideo
#////////////////////////
#HORIZONTALORIG=$(fbset | awk 'NR==3 {print $4}')
#VERTICALORIG=$(fbset | awk 'NR==3 {print $3}')
#HORIZONTALVID1="$(((HORIZONTALORIG / 2) - 400))"
#HORIZONTALVID2="$(((HORIZONTALORIG / 2) + 400))"
#VERTICALVID1="$(((VERTICALORIG / 2) - 264))"
#VERTICALVID2="$(((VERTICALORIG / 2) + 264))"
#////////////////////////



#////////////////////
#Start bakgrunn
#////////////////////

NEWHORIZONTAL=$(fbset | awk 'NR==3 {print $4}')
NEWVERTICAL=$(fbset | awk 'NR==3 {print $3}')
OLDHORIZONTAL=$(cat /home/pi/Grenfell/oldhorizontal.txt | awk 'NR==1 {print $1}')
OLDVERTICAL=$(cat /home/pi/Grenfell/oldvertical.txt | awk 'NR==1 {print $1}')

echo "gammel horsontal $OLDHORIZONTAL"
echo "NEW horisontal $NEWHORIZONTAL"


#//////////////////////////////////////////////////////////
#!!Boot omxplayer
#//////////////////////////////////////////////////////////
#cd /home/pi/Grenfell/
# omxplayer --loop --win $HORIZONTALVID1,$VERTICALVID1,$HORIZONTALVID2,$VERTICALVID2 /home/pi/Grenfell/out2.mp4 &
# sleep 5



if [ $NEWHORIZONTAL != $OLDHORIZONTAL ] || [ $NEWVERTICAL != $OLDVERTICAL ]
then
	#Mounter Grenfell som writable	 
	echo "mounter videofolder som writable"
	mount -rw /dev/mmcblk0p4 /home/pi/Grenfell/
	sleep 0.5
	cd /home/pi/Grenfell/
    inkscape -b black -z -w $NEWHORIZONTAL -h $NEWVERTICAL bg.svg -e bg.png
    sudo fbi -d /dev/fb0 -T 1 /home/pi/Grenfell/bg.png &
    #Umount
	echo "$NEWHORIZONTAL" > /home/pi/Grenfell/oldhorizontal.txt
	echo "$NEWVERTICAL" > /home/pi/Grenfell/oldvertical.txt
	sleep 0.1
	umount /dev/mmcblk0p4
	sleep 0.5
else
    sudo fbi -d /dev/fb0 -T 1 /home/pi/Grenfell/bg.png &
fi

#////////////////////////////////
#START Mounting og kopiering, USB
#////////////////////////////////

echo "forsoker mounte USB"

if [ -f /dev/sda ]; then
   sudo mount -r /dev/sda /home/pi/USB/
fi
if [ -f /dev/sda1 ]; then   
   sudo mount -r /dev/sda1 /home/pi/USB/
fi
cd /home/pi/USB/
echo "sjekker om USB er mounted"
ls

#Dersom USB
if [ "$(ls *.* | wc -l)" -gt "0" ]; then
   echo "filer på USB. sjekker filnavn"
   if [ "$(ls *.mp4 *.ogg *.wav *.mjpeg *.mkv *.mov *.3gp *.avi *.m4v *.mp3 update.* wifi.*| wc -l)" -lt "1" ]; then   
     echo "ingen gyldige filer på USB";
	else 
     echo "gyldige filer på USB"
     
	 
	 #Mounter Grenfell som writable	 
	 echo "mounter videofolder som writable"
	 mount -rw /dev/mmcblk0p4 /home/pi/Grenfell/	 
   fi
fi

#////////////////////////////////
#Konfigurasjon
#///////////////////////////////

cd /home/pi/USB
if [ "$(ls wifi.* | wc -l)" -gt "2" ]; then
  echo "flere enn en wifi-fil paa disken. kopierer ikke."
fi
if [ "$(ls wifi.* | wc -l)" -gt "0" -lt "2" ]; then
  cp wifi.* /home/pi/Grenfell/wifi.txt
 
   cd /home/pi/Grenfell
   WIFINAME="$( sed -n 1p wifi.txt )"
   PW="$( sed -n 4p wifi.txt )"
   WPA="$( sed -e  's/XXX/'$WIFINAME'/g' -e 's/YYY/'$PW'/g' wpa.txt )"
   echo "fant wifi.txt. Oppdaterer nettverk " $WIFINAME
   #echo -e $WPA > /etc/wpa_supplicant/wpa_supplicant.conf
   #FORSOK PAA KRYPTERING
   wpa_passphrase [$WIFINAME] [$PW]
   wpa_cli -i wlan0 reconfigure
   sleep 1
   ifconfig wlan0 down
   sleep 1
   ifconfig wlan0 up
fi
   
   
cd /home/pi/USB
echo "sjekker for update"
if [ "$(ls update.* | wc -l)" -gt "0" ]; then
   echo "update-fil paa USB. oppdaterer"
 
   cd /home/pi/Grenfell
   wget https://github.com/star-grit/Grenfell/blob/main/gitupdate.sh
   cp githubupdate.sh /boot/Grenfell/update.sh
   rm /boot/bootupdate.sh
   touch /home/pi/Grenfell/updateNOW.txt
   sleep 0.5
   echo "RESTARTER - vennligst fjern USB"
   sleep 3   
 #REBOOT
   reboot
	 
fi
   
cd /boot
echo "Forsoker kjore /boot/bootupdate.sh, dersom den finnes"
sh bootupdate.sh


   cd /home/pi/USB
   echo "sjekker for control-ON eller control-OFF"
   if [ "$(ls control-ON.* | wc -l)" -gt "0" ]; then
      echo "fant control-ON. skrur på MQTT"
      touch /home/pi/Grenfell/controlON.txt
   fi
   if [ "$(ls control-OFF.* | wc -l)" -gt "0" ]; then
      echo "fant control-OFF. skrur av MQTT"
      rm /home/pi/Grenfell/controlON.txt
   fi

#//////////////////////////////////
#filkopiering
#//////////////////////////////////

	cd /home/pi/USB/
	if [ "$(ls *.mp4 *.ogg *.wav *.mjpeg *.mkv *.mov *.3gp *.avi *.m4v *.mp3 | wc -l)" -gt "1" ]; then
	   echo "flere enn 1 gyldig fil paa USB - ikke spilleliste"     
	fi
	if [ "$(ls  *.mp4 *.ogg *.wav *.mjpeg *.mkv *.mov *.3gp *.avi *.m4v *.mp3 | wc -l)" -eq "1" ]; then
	  echo "gyldig fil paa USB"	  
	  echo "sletter filer som var i videofolder frafør"
	  rm -r /home/pi/Grenfell/media/*
	  echo "kopierer riktige filer"
	  if [ "$(ls *sync* | wc -l)" -gt "1" -lt "1" ]; then
		  cp /home/pi/USB/sync-video-01-01.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-01-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-01-03.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-01-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-01-05.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-01-06.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-01.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-03.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-05.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-06.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-03-01.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-03-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-03-03.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-03-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-03-05.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-03-06.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-01.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-03.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-05.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-04-06.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-05-01.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-05-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-05-03.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-05-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-05-05.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-05-06.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-06-01.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-06-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-06-03.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-06-04.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-06-05.mp4 /home/pi/Grenfell/media/
		  cp /home/pi/USB/sync-video-06-06.mp4 /home/pi/Grenfell/media/
	   else
		  cp /home/pi/USB/*.mp4 /home/pi/Grenfell/media/video.mp4
	      cp /home/pi/USB/*.mjpeg /home/pi/Grenfell/media/video.mjpeg
		  cp /home/pi/USB/*.mkv /home/pi/Grenfell/media/video.mkv
		  cp /home/pi/USB/*.mov /home/pi/Grenfell/media/video.mov
		  cp /home/pi/USB/*.3gp /home/pi/Grenfell/media/video.3gp
		  cp /home/pi/USB/*.avi /home/pi/Grenfell/media/video.avi
		  cp /home/pi/USB/*.m4v /home/pi/Grenfell/media/video.m4v
		  cp /home/pi/USB/*.mp3 /home/pi/Grenfell/media/sound.mp3
		  cp /home/pi/USB/*.ogg /home/pi/Grenfell/media/sound.ogg
		  cp /home/pi/USB/*.wav /home/pi/Grenfell/media/sound.wav
		fi
	fi
   

#///////////////////////////
#unmount usb
#///////////////////////////
   
   echo "umounter USB"
   umount /dev/sda
   umount /dev/sda1
   echo "umounter rewritable videofolder"
   umount /dev/mmcblk0p4



#------------------------------------------------------------------------

#//////////////////////////////
#tilkobling
#//////////////////////////////

#finn ip
IP=$(hostname -I | awk '{print $1}')
IP1=$(hostname -I | awk --field-separator=. '{print $1}')
IP4=$(hostname -I | awk --field-separator=. '{print $4}')
IP3=$(hostname -I | awk --field-separator=. '{print $3}')


echo "mounter videofolder, kun lesbar"
mount -r /dev/mmcblk0p4 /home/pi/Grenfell/media
echo "sjekker systemfil controlON"
if [ -f /home/pi/Grenfell/controlON.txt ]; then
   echo "fant controlON paa harddisk. sjekker nettverkskobling"
   if [ ping -q -c 1 -W 1 $IP >/dev/null ]; then
      echo "tilkoblet nettverk. starter mqtt"
	  cd /home/pi/Grenfell/mqtt-launcher/
	  python mqtt-launcher.py &
	else
      echo "ikke tilkoblet nettverk. forsøker koble til"
	  dhclient -r wlan0
      ifconfig wlan0 down
	  sleep 1
      ifconfig wlan0 up
      dhclient -v wlan0
	  ping $IP
	  sleep 1
	  ping $IP
	  sleep 1
	   if [ ping -q -c 1 -W 1 $IP >/dev/null ]; then
         echo "tilkoblet nettverk. starter mqtt"
	     cd /home/pi/Grenfell/mqtt-launcher/
	     python mqtt-launcher.py &
		 exit
       else
	     echo "greier ikke koble til nettverk. spiller av lokalt"
	   fi
   fi  
else 
   echo "ingen controlON. spiller av uten control"
fi



#Start sort bakgrunn
killall fbi
sleep 0.5
killall omxplayer.bin
sleep 0.5
sudo fbi -d /dev/fb0 -T 1 /home/pi/Grenfell/bgblack.png &



#//////////////////////////////
#avspilling
#//////////////////////////////


#sjekker sync forst pga definert navn

cd /home/pi/Grenfell/media/
if [ "$(ls sync-video? | wc -l)" -eq "1" ]; then
   echo "video med sync. sjekker nettverkskobling"
   if [ ping -q -c 1 -W 1 I ]; then
      echo "tilkoblet nettverk. starter syncvideo"
   else
      echo "ikke tilkoblet nettverk. forsøker koble til"
	  dhclient -r wlan0
      ifconfig wlan0 down
      sleep 0.5
	  ifconfig wlan0 up
      dhclient -v wlan0
	  ping $IP
	  sleep 1
	  ping $IP
	  sleep 3
	  if [ ping -q -c 1 -W 1 $IP ] ; then
         echo "tilkoblet nettverk. starter syncvideo"
	  else
	     echo "greier ikke koble til nettverk. spiller av lokalt"
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-01-01.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-01-02.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-01-03.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-01-04.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-01-05.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-01-06.mp4	  
         omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-02-01.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-02-02.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-02-03.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-02-04.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-02-05.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-02-06.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-03-01.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-03-02.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-03-03.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-03-04.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-03-05.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-03-06.mp4
         omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-04-01.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-04-02.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-04-03.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-04-04.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-04-05.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-04-06.mp4	  
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-05-01.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-05-02.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-05-03.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-05-04.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-05-05.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-05-06.mp4
         omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-06-01.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-06-02.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-06-03.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-06-04.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-06-05.mp4
	     omxplayer -b --no-osd --loop /home/pi/Grenfell/media/sync-video-06-06.mp4	  
	   fi
	fi
fi

   if [ -f /home/pi/Grenfell/media/sync-video-01-01.mp4 ]; then
     echo "video med sync -01- -01- -master-. starter"
	 ifconfig wlan0 $IP1.$IP4.$IP3.91
	 sleep 3
	 ifconfig wlan0 down
	 sleep 3
	 ifconfig wlan0 up
	 omxplayer-sync -mu /home/pi/Grenfell/media/sync-video-01-01.mp4
   fi
   
   if [ -f /home/pi/Grenfell/media/sync-video-01-02.mp4 ]; then
     echo "video med sync -4-. starter"
     omxplayer-sync -lu --destination=$IP1.$IP4.$IP3.91 /home/pi/Grenfell/media/sync-video-01-04.mp4
   fi
   if [ -f /home/pi/Grenfell/media/sync-video-01-03.mp4 ]; then
     echo "video med sync -3-. starter"
     omxplayer-sync -lu --destination=$IP1.$IP4.$IP3.91 /home/pi/Grenfell/media/sync-video-01-03.mp4
   fi
   if [ -f /home/pi/Grenfell/media/sync-video-01-04.mp4 ]; then
     echo "video med sync -4-. starter"
     omxplayer-sync -lu --destination=$IP1.$IP4.$IP3.91 /home/pi/Grenfell/media/sync-video-01-04.mp4
   fi
   if [ -f /home/pi/Grenfell/media/sync-video-01-05.mp4 ]; then
     echo "video med sync -5-. starter"
     omxplayer-sync -lu --destination=$IP1.$IP4.$IP3.91 /home/pi/Grenfell/media/sync-video-01-05.mp4
   fi
   if [ -f /home/pi/Grenfell/media/sync-video-01-06.mp4 ]; then
     echo "video med sync -6-. starter"
     omxplayer-sync -lu --destination=$IP1.$IP4.$IP3.91 /home/pi/Grenfell/media/sync-video-01-06.mp4
   fi
 
   if [ -f /home/pi/Grenfell/media/sync-video-02-01.mp4 ]; then
     echo "video med sync -04- -01- -master-. starter"
	 ifconfig wlan0 $IP1.$IP4.$IP3.94
	 sleep 3
	 ifconfig wlan0 down
	 sleep 3
	 ifconfig wlan0 up
	 sleep 3
	 omxplayer-sync -mu /home/pi/Grenfell/media/sync-video-02-01.mp4
   fi
   
   if [ -f /home/pi/Grenfell/media/sync-video-02-02.mp4 ]; then
     echo "video med sync -2-2-. starter"
     omxplayer-sync -lu --destination=$IP1.$IP4.$IP3.92 //home/pi/Grenfell/media/sync-video-02-02.mp4
   fi
   if [ -f /home/pi/Grenfell/media/sync-video-02-03.mp4 ]; then
     echo "video med sync -2-3-. starter"
     omxplayer-sync -lu --destination=$IP1.$IP4.$IP3.92 //home/pi/Grenfell/media/sync-video-02-03.mp4
   fi
   if [ -f /home/pi/Grenfell/media/sync-video-02-04.mp4 ]; then
     echo "video med sync -2-4-. starter"
     omxplayer-sync -lu  --destination=$IP1.$IP4.$IP3.92 //home/pi/Grenfell/media/sync-video-02-04.mp4
   fi
   if [ -f /home/pi/Grenfell/media/sync-video-02-05.mp4 ]; then
     echo "video med sync -2-5-. starter"
     omxplayer-sync -lu  --destination=$IP1.$IP4.$IP3.92 //home/pi/Grenfell/media/sync-video-02-05.mp4
   fi
   if [ -f /home/pi/Grenfell/media/sync-video-02-06.mp4 ]; then
     echo "video med sync -2-6-. starter"
     omxplayer-sync -lu  --destination=$IP1.$IP4.$IP3.92 //home/pi/Grenfell/media/sync-video-02-06.mp4
   fi
 
 
 #//////////////////////////////////////

if [ "$(ls  *.mp4 *.ogg *.wav *.mjpeg *.mkv *.mov *.3gp *.avi *.m4v *.mp3 | wc -l)" -eq "1" ]; then
   echo "video uten sync. starter"
   FILENAME=$(ls *.mp4 *.ogg *.wav *.mjpeg *.mkv *.mov *.3gp *.avi *.m4v *.mp3 | awk '{print $1}')
   omxplayer -b --no-osd --loop //home/pi/Grenfell/media/$FILENAME
   exit
fi

#//////////////////////////////////////

echo "nå har visst alt sluttet, dette er slutten"
exit

Pi Presentation
===============

This project enables you to quickly turn a RaspberryPi running Raspbian into a display of content 
stored in a format that LibreOffice's Impress can open and display.

Installation
------------
To install the presentation software follow these four steps:
```
sudo apt-get install git
git clone https://github.com/jjshoe/pi_presentation.git /tmp/pi_presentation
sudo cp /tmp/pi_presentation/30-usb.rules /etc/udev/rules.d/30-usb.rules
sudo cp /tmp/pi_presentation/pi_presentation.pl /usr/local/bin/pi_presentation.pl
```

You should double check your permissions and ownership:
```
sudo chown root:root /etc/udev/rules.d/30-usb.rules /usr/local/bin/pi_presentation.pl
sudo chmod 644 /etc/udev/rules.d/30-usb.rules
sudo chmod 744 /usr/local/bin/pi_presentation.pl
```

USB Drive Layout
----------------
Pi Presentation looks for any USB storage device it can mount. After it mounts the 
device it looks for a directory in the root of your USB device called: ```presentation```. 
Inside the presentation directory it looks for a presentation file name that begins 
wih ```current```. Any file ending LibreOffice Impress supports should work.


Technical
---------
### UDEV

Udev rules control what happens when a new device is discovered on the dbus. For a 
full understanding of udev rules check out 
[Daniel Drake's great tutorial](http://www.reactivated.net/writing_udev_rules.html). 

#### First Rule
```KERNEL=="sd?[0-9]", SUBSYSTEMS=="usb", ACTION=="add", RUN=="/usr/local/bin/pi_presentation.pl %k start", ENV{UDISKS_PRESENTATION_HIDE}="1"```

#### Explanation
Match any kernel device we see that starts with sd, followed by any single character,
followed by a single number 0 through 9. It should be from the USB subsystem, and 
we only want to act when the device is added to the system. The run command is called
with two options, ```%k``` and ```start```. The start option is used by the perl 
script to denote the flow of code to take. The variable ```%k``` is specific to udev, 
and stands for the device that was added. Example values for ```%k``` are ```sda1``` 
```sdc3``` and ```sdd2```. The last pice ```ENV{UDISKS_PRESENTATION_HIDE}="1"``` is 
an environment variable we set for the running program. It's a way to tell the 
presentation system to ignore the fact that a disk was added. This prevents a popup 
from coming up asking you what you would like to do with this device, however this 
also stops it from being mounted.

#### Second Rule
```KERNEL=="sd?[0-9]", SUBSYSTEMS=="usb", ACTION=="remove", RUN=="/usr/local/bin/pi_presentation.pl %k stop", ENV{UDISKS_PRESENTATION_HIDE}="1"```

#### Explanation
The ```KERNEL``` ```SUBSYSTEMS``` and ```ENV``` sections all match the first rule. The 
```ACTION``` has changed to ```remove``` and the ```RUN``` section passes in ```stop``` 
instead of ```start```. That means that this rule matches when the device is removed, 
and we let the script know to stop the presentation.

### Script
The script that gets called by udev, ```pi_presentation.pl```, is a perl script. It has 
six variables at the top that can be tweaked to match your RaspberryPi linux 
distribution specifics. After defining these variables it takes two main program flows, 
start and stop.

#### Variables
```$mount_path``` Where your USB device should be mounted (```/media/PI_PRESENTATION```) 
```$mount_cmd``` Where to find the command to mount devices (```/bin/mount```)
```$umount_cmd``` Where to find the command to un-mount devices (```/bin/umount```)
```$libreoffice_Cmd``` Where to find the command to launch LibreOffice (```/usr/bin/libreoffice```)
```$pid_path``` Where to write out the PID of the running scripts (```/var/run/pi_presentation.pid```)
```$x_user``` The name of the user running X (```pi```)

#### Start
1. Fork
    1. Parent Process
       1. Make the directory ```$mount_path``` (default: ```/media/PI_PRESENTATION```) where we will mount the device 
       1. Set ourselves as the parent to a process group
       1. Mount the device read only
       1. Launch LibreOffice's Impress to play our presentation
    1. Child Process
        1. Write out process ID to ```$pid_path``` (default: ```/var/run/pi_presentation.pid```)

#### Stop
1. Read the process ID in from ```$pid_path``` (default: ```/var/run/pi_presentation.pid```)
1. Send a TERM (-15) to our process ID. Since we setup a process group this takes care of all children. 
1. Delete ```$pid_path``` (default: ```/var/run/pi_presentation.pid```)
1. Repeatedly attempt to un-mount ```$mount_path``` (default: ```/media/PI_PRESENTATION```) the device until succesful 

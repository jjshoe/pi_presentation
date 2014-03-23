#!/usr/bin/perl

use strict;
use warnings;

# Feel free to adjust these values to fit your RaspberryPi distro
my $mount_path      = '/media/PI_PRESENTATION';
my $mount_cmd       = '/bin/mount';
my $umount_cmd      = '/bin/umount';
my $libreoffice_cmd = '/usr/bin/libreoffice';
my $pid_path        = '/var/run/pi_presentation.pid';
my $x_user          = 'pi';

# If you need help with something below consider making an issue: https://github.com/jjshoe/pi_presentation/issues/new
my $device = $ARGV[0];
my $command = $ARGV[1];

# Let root(udev user) display to the end user's display
$ENV{'DISPLAY'} = ':0';
$ENV{'XAUTHORITY'} = '/home/' . $x_user . '/.Xauthority';

if ($command eq 'start')
{
  # We need to write out the pid file so we can stop the presentation before umounting
  my $pid = fork();

  if ($pid == 0)
  {
    # Cheaper to call mkdir then check if it exists
    mkdir($mount_path);

    # Make sure we can kill off our children easily
    setpgrp(0, 0);

    # Mount up the usb device
    system("$mount_cmd -o ro /dev/$device $mount_path");

    # Start impress (LibreOffice's answer to powerpoint) without a splash screen, don't ask us to recover anything, and go straight into the presentation
    system("$libreoffice_cmd -show $mount_path/presentation/current.* --nologo --nolockcheck --norestore");
  }
  else
  {
    # Write the PID to a pid file on disk
    open(my $pid_fh, '>', $pid_path);
    print $pid_fh $pid;
    close($pid_fh);
  }
}
else
{
  my $pid;

  # Open up the PID file and read it in
  open(my $pid_fh, '<', $pid_path);
  {
    local $/;
    $pid = <$pid_fh>;
  }
  close($pid_fh);

  # Try to stop the presentation. The - is to kill the process group and is needed.
  kill '-15', $pid;

  # Unlink the PID file
  unlink($pid_path);

  while (my $umount_result = system("$umount_cmd $mount_path"))
  {
    if ($umount_result == 0)
    {
      exit;
    }

    # Device is busy, try again shortly
    sleep(5);
  }
}

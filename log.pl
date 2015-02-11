#!/usr/bin/perl
# Doomsday
# Copyright (C) 2003  Erik Fears
# ALL RIGHTS RESERVED

# log
#
# Log data to strerr or file

sub do_log #($data)
{
   my $data = $_[0];
   print STDOUT "[" . scalar localtime() . "] " . $data . "\n";
}

return true;

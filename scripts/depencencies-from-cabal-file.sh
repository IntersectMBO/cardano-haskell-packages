#!/usr/bin/env bash

# Check if a filename was provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <cabal file to parse>"
    exit 1
fi

FILE_TO_PARSE="$1"

# Check if the file exists
if [ ! -f "$FILE_TO_PARSE" ]; then
    echo "Error: File '$FILE_TO_PARSE' not found."
    exit 1
fi

# Perl script to extract dependencies 
perl -e '
  use strict;
  use warnings;

  # state:
  # 0 - outside block
  # 1 - in block (next should be dependency)
  # 2 - in block (but missing comma)
  my $state = 0;

  my $start_tag_re = qr/^\s*build-depends:/i;
  my $other_start_tag_re = qr/^\s*[a-zA-Z]+(-?[a-zA-Z0-9])*:/i;
  my $item_re = qr/([a-zA-Z]+(-?[a-zA-Z0-9])*)/;
  my $comma_item_re = qr/,([a-zA-Z]+(-?[a-zA-Z0-9])*)/;
  my $qualifiers_re = qr/([^{,]|({[^}]*}))+/;

  my @lines = <>;
  foreach my $line (@lines) {
    if ($line =~ /^\s*-- /) {
      next;
    }
    if ($line =~ /^\s*if$/) {
      next;
    }
    if ($line =~ /^\s*if /) {
      next;
    }
    if ($line =~ /^\s*else$/) {
      next;
    }
    if ($line =~ /^\s*else /) {
      next;
    }
    if ($line =~ $start_tag_re) {
      $state = 1;
      $line =~ s/$start_tag_re//i;
    } else { 
      if ($line =~ $other_start_tag_re) {
        $state = 0;
      }
    }
    my @tokens = split(/\s+/, $line);
    foreach my $token (@tokens) {
      while ($token !~ /^\s*$/) {
        if ($state == 1 && $token =~ $item_re) {
           print "$1\n";
           $token =~ s/$item_re//;
           $state = 2;
        } elsif ($state == 2 && $token =~ $comma_item_re) {
           print "$1\n";
           $token =~ s/$comma_item_re//;
           $state = 1;
        } elsif ($state == 2 && $token =~ /,/) {
           $token =~ s/,//;
           $state = 1;
        } elsif ($state == 2 && $token =~ $qualifiers_re) {
           $token =~ s/$qualifiers_re//;
        } else {
           $token = "";
        }
      }
    }
  }
' "$FILE_TO_PARSE"


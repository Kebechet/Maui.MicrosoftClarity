#!/usr/bin/env perl
#
# Replaces <PackageReleaseNotes> in a binding csproj with a single entry: the version
# being published, and nothing else. Older entries are not kept - the history lives in
# git and in the per-version notes already published on nuget.org.
#
# The file is read and written as bytes, so its BOM and line endings are preserved.
#
# Usage: perl scripts/set-release-note.pl <csproj> "<version>: <text>"

use strict;
use warnings;

my ($file, $note) = @ARGV;
die "usage: set-release-note.pl <csproj> <note>\n" unless defined $file && defined $note && length $note;
die "note must not contain XML markup: $note\n" if $note =~ /[<>&]/;

open my $in, '<:raw', $file or die "$file: $!\n";
my $xml = do { local $/; <$in> };
close $in;

# A flag rather than "did the text change?": re-running with the note already in place is
# a no-op, and a no-op must not look like a missing element.
my $matched = 0;
my $new = $xml =~ s{(<PackageReleaseNotes>)(.*?)(</PackageReleaseNotes>)}{
    $matched = 1;
    $1 . $note . $3;
}smer;

die "no <PackageReleaseNotes> element found in $file\n" unless $matched;

open my $out, '>:raw', $file or die "$file: $!\n";
print $out $new;
close $out;

#!/usr/bin/env perl
#
# Prepends one entry to <PackageReleaseNotes> in a binding csproj, keeping the earlier
# entries - one entry per line, newest first - so nuget.org shows a readable history
# instead of one 600-character line:
#
#   <PackageReleaseNotes>
#   3.9.0.0: bumped native Clarity Android SDK from 3.8.2 to 3.9.0. Changelog: ...
#   3.8.2.1: the Clarity AAR is now consumed via AndroidMavenLibrary ...
#   </PackageReleaseNotes>
#
# The first run converts the legacy single-line "A: ... B: ..." format by splitting on
# the "<version>: " markers. An existing entry for the same version is replaced, so a
# re-run cannot stack duplicates. Entries are not indented on purpose: nuget.org renders
# the notes as markdown, where four leading spaces would turn a line into a code block.
# The file is read and written as bytes, so its BOM and line endings are preserved.
#
# Usage: perl scripts/prepend-release-note.pl <csproj> "<version>: <text>"

use strict;
use warnings;

my ($file, $note) = @ARGV;
die "usage: prepend-release-note.pl <csproj> <note>\n" unless defined $file && defined $note && length $note;

open my $in, '<:raw', $file or die "$file: $!\n";
my $xml = do { local $/; <$in> };
close $in;

my $eol = $xml =~ /\r\n/ ? "\r\n" : "\n";
my ($version) = $note =~ /^(\S+):\s/;

# A flag rather than "did the text change?": re-running with an entry that is already
# present is a no-op, and a no-op must not look like a missing element.
my $matched = 0;
my $new = $xml =~ s{^([ \t]*)(<PackageReleaseNotes>)(.*?)(</PackageReleaseNotes>)}{
    $matched = 1;
    my ($indent, $open, $body, $close) = ($1, $2, $3, $4);
    my @entries;
    if ($body =~ /\n/) {
        @entries = map { s/^\s+|\s+$//gr } split /\r?\n/, $body;
    } else {
        $body =~ s/^\s+|\s+$//g;
        @entries = split /\s+(?=\d+(?:\.\d+){2,3}:\s)/, $body;
    }
    @entries = grep { length } @entries;
    @entries = grep { !/^\Q$version\E:\s/ } @entries if defined $version;
    $indent . $open . $eol . join($eol, $note, @entries) . $eol . $indent . $close;
}smer;

die "no <PackageReleaseNotes> element found in $file\n" unless $matched;

open my $out, '>:raw', $file or die "$file: $!\n";
print $out $new;
close $out;

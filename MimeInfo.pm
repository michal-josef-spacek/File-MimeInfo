package File::MimeInfo;

use strict;
use Carp;
use File::Spec;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(mimetype);
our $VERSION = '0.1';

our @DIRS;

my $rootdir = File::Spec->rootdir();
our @xdg_data_dirs = (
	File::Spec->catdir($rootdir, qw/usr share/),
	File::Spec->catdir($rootdir, qw/usr local share/),
);
our $xdg_data_home = $ENV{HOME}
	? File::Spec->catdir($ENV{HOME}, qw/.local share/)
	: undef ;

our (@globs, %literal, %extension); # data hashes
# @globs = [ [ qr//, $mime_string ], ... ]
# %literal contains literal matches
# %extension contains extensions (globs matching /^\*(\.\w)+$/ )

rehash(); # initialise data

sub new { bless $VERSION, shift } # what else is there to bless ?

sub mimetype {
	my $file = pop;
	my $recurs = pop;

	(undef, undef, $file) = File::Spec->splitpath($file) unless $recurs;
#	print "debug: Searching mimetype for '$file'\n";

	return $literal{$file} if exists $literal{$file};

	if ($file =~ /\.(\w+(\.\w+)*)$/) {
		my @ext = split /\./, $1;
		if ($#ext) {
			while (@ext) {
				my $ext = join('.', @ext);
				return $extension{$ext}
					if exists $extension{$ext};
				shift @ext;
			}
		}
		else {
			return $extension{$ext[0]}
				if exists $extension{$ext[0]};
		}
	}

	for (@globs) {
		next unless $file =~ $_->[0];
		return $_->[1];
	}

	return mimetype(++$recurs, lc($file)) unless $recurs || $file !~ /[A-Z]/;
	# recursing for case insensitive version
	return undef;
}

sub dirs {
	return @DIRS if @DIRS;
	my @dirs = 
		$ENV{XDG_DATA_DIRS}
		? reverse(split ':', $ENV{XDG_DATA_DIRS})
		: @xdg_data_dirs;

	push @dirs, $ENV{XDG_DATA_HOME} || $xdg_data_home;

	return @dirs;
}

sub rehash {
	(@globs, %literal, %extension) = ((), (), ()); # clear data
	my $success = 0;
	for ( dirs() ) {
		my $file = File::Spec->catfile($_, qw/mime globs/);
		next unless -f $file;
#		print "debug: Going to read '$file'\n";
		open MIME, $file || croak "Could not open file '$file' for reading" ;
		my ($string, $glob);
		while (<MIME>) {
			next if /^\s*#/; # skip comments
			chomp;
			($string, $glob) = split /:/, $_, 2;
			unless ($glob =~ /[\?\*\[]/) { $literal{$glob} = $string }
			elsif ($glob =~ /^\*\.(\w+(\.\w+)*)$/) { $extension{$1} = $string }
			else { unshift @globs, [_glob_to_regexp($glob), $string] }
		}
		close MIME;
		$success++;
	}
	carp "You don't seem to have any mime info files." unless $success;
}

sub _glob_to_regexp {
	my $glob = shift;
	$glob =~ s/\./\\./g;
	$glob =~ s/([?*])/.$1/g;
	$glob =~ s/([^\w\/\\\.\?\*\[\]])/\\$1/g;
	qr/^$glob$/;
}

1;

__END__

=head1 NAME

File::MimeInfo - Guess file type by extension

=head1 SYNOPSIS

  use File::MimeInfo;
  my $mime_type = mimetype($file);

=head1 DESCRIPTION

This module can be used to determine the mime type of a file. It
tries to implement the freedesktop specification for a shared
MIME database.

For this module shared-mime-info-spec 0.11 and basedir-spec 0.5 where used.

Currently only the globs file is used. No real magic checking is
used. This is because the goal was to make a module that would
share filetypes with I<rox>, the current I<rox> implementation also only
uses globs.

( See L</SEE ALSO> for url's )

=head1 EXPORT

The method C<mimetype> is exported by default.

=head1 METHODS

=over 4

=item C<new()>

Simple constructor to allow Object Oriented use of this module.

=item C<mimetype($file)>

Returns a mime-type string for C<$file>, returns undef on failure.
Since currently only globs are supported, the file doesn't need to exist.

=item C<dirs()>

Lists all directories that would be scanned when rehashing, they don't need
to exist or need have a "mime" subdir.

The default behaviour can be overloaded by setting global variable C<@DIRS>,
this is mainly used for testing purposes.

I<It lists the least important dir first.>

=item C<rehash()>

Rehash the data files. Glob information is preparsed

=back

=head1 ENVIRONMENT

This module uses the following two environment variables when looking for
available data file.

I<Quoting basedir-spec 0.5 :>

=over 4

=item XDG_DATA_HOME

Defines the base directory relative to which user specific data files 
should be stored.
If C<$XDG_DATA_HOME> is either not set or empty,
a default equal to C<$HOME/.local/share> is used.

Mime data could be found in C<$XDG_DATA_HOME/mime>.

=item XDG_DATA_DIRS

Defines the preference-ordered set of base directories to search for data 
files in addition to the C<$XDG_DATA_HOME> base directory. 
The directories in C<$XDG_DATA_DIRS> should be seperated with a colon ':'.
If C<$XDG_DATA_DIRS> is either not set or empty, a value equal 
to C</usr/local/share/:/usr/share/> should is used.

Mime data could be found in the "mime" subdirs of these dirs.

=back

The order of base directories denotes their importance; 
the first directory listed is the most important. 
When the same information is defined in multiple places 
the information defined relative to the more 
important base directory takes precedent. 
The base directory defined by C<$XDG_DATA_HOME> 
is considered more important than any of the base 
directories defined by C<$XDG_DATA_DIRS>.

=head1 DIAGNOSTICS

This module throws a warning if it couldn't find any data files.
This can either mean that you don't have the freedesktop mime 
info database installed, or your environment variables point to the
wrong places. 

An exception is thrown when it can't open a data file it found.
This should never happen, since the mime info should logically be world
readable.

=head1 AUTHOR

Jaap Karssenberg || Pardus [Larus] E<lt>j.g.karssenberg@student.utwente.nlE<gt>

Copyright (c) 2003 Jaap G Karssenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item other CPAN modules

L<File::MMagic>

=item freedesktop specifications used

L<http://www.freedesktop.org/standards/shared-mime-info-spec/>,
L<http://www.freedesktop.org/standards/basedir-spec/>

=item freedesktop mime database

L<http://www.freedesktop.org/software/shared-mime-info/>

=item other programs using this mime system

L<http://rox.sourceforge.net>

=cut

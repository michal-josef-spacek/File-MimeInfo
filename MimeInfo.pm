package File::MimeInfo;

use strict;
use Carp;
use File::Spec;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(mimetype);
our @EXPORT_OK = qw(describe globs inodetype);
our $VERSION = '0.4';
our $DEBUG;

my $rootdir = File::Spec->rootdir();
our @xdg_data_dirs = (
	File::Spec->catdir($rootdir, qw/usr local share/),
	File::Spec->catdir($rootdir, qw/usr share/),
);
our $xdg_data_home = $ENV{HOME}
	? File::Spec->catdir($ENV{HOME}, qw/.local share/)
	: undef ;

our ($DIR, @globs, %literal, %extension, $dir, $LANG);
# $DIR can be used to overload the search path used
# @globs = [ [ 'glob', qr//, $mime_string ], ... ]
# %literal contains literal matches
# %extension contains extensions (globs matching /^\*(\.\w)+$/ )
# $dir is the dir used by last rehash
# $LANG can be used to set a default language for the comments

rehash(); # initialise data

sub new { bless \$VERSION, shift } # what else is there to bless ?

sub mimetype {
	my $file = pop
		|| croak 'subroutine "mimetype" needs a filename as argument';
	return 
		inodetype($file) ||
		globs($file)	 ||
		default($file);
}

sub inodetype {
	my $file = pop;
	return
	(-d $file) ? 'inode/directory'   :
	(-l $file) ? 'inode/symlink'     :
	(-p $file) ? 'inode/fifo'        :
	(-c $file) ? 'inode/chardevice'  :
	(-b $file) ? 'inode/blockdevice' :
	(-S $file) ? 'inode/socket'      : undef ;
}

sub globs {
	my $file = pop || croak 'subroutine "globs" needs a filename as argument';
	(undef, undef, $file) =  File::Spec->splitpath($file);
	print "> Checking globs for basename '$file'\n" if $DEBUG;

	return $literal{$file} if exists $literal{$file};

	if ($file =~ /\.(\w+(\.\w+)*)$/) {
		my @ext = split /\./, $1;
		if ($#ext) {
			while (@ext) {
				my $ext = join('.', @ext);
				print "> Checking for extension '.$ext'\n" if $DEBUG;
				return $extension{$ext}
					if exists $extension{$ext};
				shift @ext;
			}
		}
		else {
			print "> Checking for extension '.$ext[0]'\n" if $DEBUG;
			return $extension{$ext[0]}
				if exists $extension{$ext[0]};
		}
	}

	for (@globs) {
		next unless $file =~ $_->[1];
		print "> This file name matches \"$_->[0]\"\n" if $DEBUG;
		return $_->[2];
	}

	return globs(lc $file) if $file =~ /[A-Z]/; # recurs
	return undef;
}

sub default {
	my $file = pop || croak 'subroutine "default" needs a filename as argument';
	return undef unless -f $file;
	print "> File exists, trying default method\n" if $DEBUG;
	return 'text/plain' if -z $file;
	
	my $line;
	open FILE, $file || return undef;
	binmode FILE, ':utf8';
	read FILE, $line, 10;
	close FILE;

	$line =~ s/\s//g; # \n and \t are also control chars
	return 'text/plain' unless $line =~ /[\x00-\x1F\xF7]/;
	print "> First 10 bytes of the file contain control chars\n" if $DEBUG;
	return 'application/octet-stream';
}

sub _find_dir {
	return $dir = $DIR if $DIR;

	for my $d (
		($ENV{XDG_DATA_HOME} || $xdg_data_home),
		( $ENV{XDG_DATA_DIRS}
			? split(':', $ENV{XDG_DATA_DIRS})
			: @xdg_data_dirs
		)
	) {
		next unless -f File::Spec->catfile($d, qw/mime globs/);
		$dir = File::Spec->catdir($d, q/mime/);
		last
	}

	croak "You don't seem to have a mime-info database." unless $dir;
	return $dir;
}

sub rehash {
	(@globs, %literal, %extension) = ((), (), ()); # clear data
	my $success = 0;
	&_find_dir;
	my $file = File::Spec->catfile($dir, q/globs/);
	open MIME, $file || croak "Could not open file '$file' for reading" ;
	my ($string, $glob);
	while (<MIME>) {
		next if /^\s*#/; # skip comments
		chomp;
		($string, $glob) = split /:/, $_, 2;
		unless ($glob =~ /[\?\*\[]/) { $literal{$glob} = $string }
		elsif ($glob =~ /^\*\.(\w+(\.\w+)*)$/) { $extension{$1} = $string }
		else { unshift @globs, [$glob, _glob_to_regexp($glob), $string] }
	}
	close MIME || croak "Could not open file '$file' for reading" ;
}

sub _glob_to_regexp {
	my $glob = shift;
	$glob =~ s/\./\\./g;
	$glob =~ s/([?*])/.$1/g;
	$glob =~ s/([^\w\/\\\.\?\*\[\]])/\\$1/g;
	qr/^$glob$/;
}

sub describe {
	my $mt = pop || croak 'subroutine "describe" needs a mimetype as argument';
	my $file = File::Spec->catfile($dir, split '/', "$mt.xml");
	return undef unless -e $file;
	my $att =  $LANG ? qq{xml:lang="$LANG"} : '';
	open XML, $file || croak "Could not open file '$file' for reading";
	binmode XML, ':utf8';
	my $desc;
	while (<XML>) {
		next unless m!<comment\s*$att>(.*?)</comment>!;
		$desc = $1;
		last;
	}
	close XML;
	return $desc;
}

1;

__END__

=head1 NAME

File::MimeInfo - Determine file type

=head1 SYNOPSIS

  use File::MimeInfo;
  my $mime_type = mimetype($file);

=head1 DESCRIPTION

This module can be used to determine the mime type of a file. It
tries to implement the freedesktop specification for a shared
MIME database.

For this module shared-mime-info-spec 0.11 and basedir-spec 0.5 where used.

This packege only uses the globs file. No real magic checking is
used. The L<File::MimeInfo::Magic> package is provided for magic typing.

=head1 EXPORT

The method C<mimetype> is exported by default.
The methods C<inodetype>, C<globs> and C<describe> can be exported on demand.

=head1 METHODS

=over 4

=item C<new()>

Simple constructor to allow Object Oriented use of this module.
If you want to use this, use the package as C<use File::MimeInfo ();>
to avoid importing sub C<mimetype>.

=item C<mimetype($file)>

Returns a mime-type string for C<$file>, returns undef on failure.

This method bundles C<inodetype> and C<globs>.

If this doesn't work the file is read and the mime-type defaults
to 'text/plain' or to 'application/octet-stream' when the first ten chars
of the file match ascii control chars (white spaces excluded).
If the file doesn't exist or isn't readable C<undef> is returned.
Returns a mime-type string for C<$file>, returns undef on failure.

=item C<inodetype($file)>

Returns a mimetype in the 'inode' namespace or undef when the file is 
actually a normal file.

=item C<globs($file)>

Returns a mime-type string for C<$file> based on the glob rules, returns undef on
failure. The file doesn't need to exist.

=item C<describe($mimetype)>

Returns a description of this mimetype as supplied by the mime info database.
You can set the global variable C<$File::MimeInfo::LANG> to specify a language,
this should be the two letter language code used in the xml files. Returns undef when 
there seems to be no xml file for this mimetype, this could very well mean the 
mimetype doesn't exist, it could also mean that the language you specified wasn't found.

I<Currently no real xml parsing is done, it trust the xml files are nicely formatted.>

=item C<rehash()>

Rehash the data files. Glob information is preparsed when this method is called.

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

Mime data should be found in the "mime" subdir of one
of these dirs. The dir that should be used can be hardcoded with the
variable C<$File::MimeInfo::DIR>, this is used for testing purposes.

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

This module throws an exception when it can't find any data files, when it can't
open a data file it found for reading or when a subroutine doesn't get enough arguments.
In the first case youn either don't have the freedesktop mime info database installed, 
or your environment variables point to the wrong places,
in the second case you have the database installed, but it is broken 
(the mime info database should logically be world readable).

=head1 TODO

Make an option for using some caching mechanism to reduce init time.

Make L</describe> do real xml parsing?

=head1 BUGS

Non I know of, please mail me when you encounter one.

=head1 AUTHOR

Jaap Karssenberg || Pardus [Larus] E<lt>pardus@cpan.org<gt>

Copyright (c) 2003 Jaap G Karssenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<File::MimeInfo::Magic>

=over 4

=item related CPAN modules

L<File::MMagic>

=item freedesktop specifications used

L<http://www.freedesktop.org/standards/shared-mime-info-spec/>,
L<http://www.freedesktop.org/standards/basedir-spec/>

=item freedesktop mime database

L<http://www.freedesktop.org/software/shared-mime-info/>

=item other programs using this mime system

L<http://rox.sourceforge.net>

=cut

package File::MimeInfo;

use strict;
use Carp;
use Fcntl 'SEEK_SET';
use File::BaseDir qw/xdg_data_files/;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(mimetype);
our @EXPORT_OK = qw(describe globs inodetype);
our $VERSION = '0.9';
our $DEBUG;

our (@globs, %literal, %extension, $LANG);
# @globs = [ [ 'glob', qr//, $mime_string ], ... ]
# %literal contains literal matches
# %extension contains extensions (globs matching /^\*(\.\w)+$/ )
# $LANG can be used to set a default language for the comments

rehash(); # initialise data

sub new { bless \$VERSION, shift } # what else is there to bless ?

sub mimetype {
	my $file = pop
		|| croak 'subroutine "mimetype" needs a filename as argument';
	croak 'You should use File::MimeInfo::Magic to check open filehandles' if ref $file;
	return 
		inodetype($file) ||
		globs($file)	 ||
		default($file);
}

sub inodetype {
	my $file = pop;
	print STDERR "> Checking inode type\n" if $DEBUG;
	return	(-d $file) ? 'inode/directory'   :
		(-l $file) ? 'inode/symlink'     :
		(-p $file) ? 'inode/fifo'        :
		(-c $file) ? 'inode/chardevice'  :
		(-b $file) ? 'inode/blockdevice' :
		(-S $file) ? 'inode/socket'      : undef ;
}

sub globs {
	my $file = pop || croak 'subroutine "globs" needs a filename as argument';
	print STDERR "> Checking globs for basename '$file'\n" if $DEBUG;

	return $literal{$file} if exists $literal{$file};

	if ($file =~ /\.(\w+(\.\w+)*)$/) {
		my @ext = split /\./, $1;
		if ($#ext) {
			while (@ext) {
				my $ext = join('.', @ext);
				print STDERR "> Checking for extension '.$ext'\n" if $DEBUG;
				return $extension{$ext}
					if exists $extension{$ext};
				shift @ext;
			}
		}
		else {
			print STDERR "> Checking for extension '.$ext[0]'\n" if $DEBUG;
			return $extension{$ext[0]}
				if exists $extension{$ext[0]};
		}
	}

	for (@globs) {
		next unless $file =~ $_->[1];
		print STDERR "> This file name matches \"$_->[0]\"\n" if $DEBUG;
		return $_->[2];
	}

	return globs(lc $file) if $file =~ /[A-Z]/; # recurs
	return undef;
}

sub default {
	my $file = pop || croak 'subroutine "default" needs a filename as argument';
	
	my $line;
	unless (ref $file) {
		return undef unless -f $file;
		print STDERR "> File exists, trying default method\n" if $DEBUG;
		return 'text/plain' if -z $file;
	
		open FILE, $file || return undef;
		binmode FILE, ':utf8' unless $] < 5.008;
		read FILE, $line, 10;
		close FILE;
	}
	else {
		print STDERR "> Trying default method on object\n" if $DEBUG;

		$file->seek(0, SEEK_SET);
		$file->read($line, 10);
	}

	{
		no warnings; # warnings can be thrown when input is neither ascii or utf8
		$line =~ s/\s//g; # \n and \t are also control chars
		return 'text/plain' unless $line =~ /[\x00-\x1F\xF7]/;
	}
	print STDERR "> First 10 bytes of the file contain control chars\n" if $DEBUG;
	return 'application/octet-stream';
}

sub rehash {
	(@globs, %literal, %extension) = ((), (), ()); # clear data
	my $done;
	++$done && _hash_globs($_) for reverse xdg_data_files('mime/globs');
	print STDERR << 'EOE' unless $done;
You don't seem to have a mime-info database.
See http://freedesktop.org/Software/shared-mime-info
EOE
}

sub _hash_globs {
	my $file = shift;
	open GLOB, $file || croak "Could not open file '$file' for reading" ;
	my ($string, $glob);
	while (<GLOB>) {
		next if /^\s*#/; # skip comments
		chomp;
		($string, $glob) = split /:/, $_, 2;
		unless ($glob =~ /[\?\*\[]/) { $literal{$glob} = $string }
		elsif ($glob =~ /^\*\.(\w+(\.\w+)*)$/) { $extension{$1} = $string }
		else { unshift @globs, [$glob, _glob_to_regexp($glob), $string] }
	}
	close GLOB || croak "Could not open file '$file' for reading" ;
}

sub _glob_to_regexp {
	my $glob = shift;
	$glob =~ s/\./\\./g;
	$glob =~ s/([?*])/.$1/g;
	$glob =~ s/([^\w\/\\\.\?\*\[\]])/\\$1/g;
	qr/^$glob$/;
}

sub describe {
	shift if ref $_[0];
	my ($mt, $lang) = @_;
	croak 'subroutine "describe" needs a mimetype as argument' unless $mt;
	$lang = $LANG unless defined $lang;
	my $att =  $lang ? qq{xml:lang="$lang"} : '';
	my $desc;
	for my $file (xdg_data_files('mime', split '/', "$mt.xml")) {
		$desc = ''; # if a file was found, return at least empty string
		open XML, $file || croak "Could not open file '$file' for reading";
		binmode XML, ':utf8' unless $] < 5.008;
		while (<XML>) {
			next unless m!<comment\s*$att>(.*?)</comment>!;
			$desc = $1;
			last;
		}
		close XML || croak "Could not open file '$file' for reading";
		last if $desc;
	}
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

For this module shared-mime-info-spec 0.12 was used.

This package only uses the globs file. No real magic checking is
used. The L<File::MimeInfo::Magic> package is provided for magic typing.

If you want to detemine the mimetype of data in a memory buffer you should
use L<File::MimeInfo::Magic> in combination with L<IO::Scalar>.

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

If these methods are unsuccessfull the file is read and the mime-type defaults
to 'text/plain' or to 'application/octet-stream' when the first ten chars
of the file match ascii control chars (white spaces excluded).
If the file doesn't exist or isn't readable C<undef> is returned.

=item C<inodetype($file)>

Returns a mimetype in the 'inode' namespace or undef when the file is 
actually a normal file.

=item C<globs($file)>

Returns a mime-type string for C<$file> based on the glob rules, returns undef on
failure. The file doesn't need to exist.

=item C<describe($mimetype, $lang)>

Returns a description of this mimetype as supplied by the mime info database.
You can specify a language with the optional parameter C<$lang>, this should be 
the two letter language code used in the xml files. Also you can set the global 
variable C<$File::MimeInfo::LANG> to specify a language.

This method returns undef when no xml file was found (i.e. the mimetype 
doesn't exist in the database). It returns an empty string when the xml file doesn't
contain a description in the language you specified.

I<Currently no real xml parsing is done, it trust the xml files are nicely formatted.>

=item C<rehash()>

Rehash the data files. Glob information is preparsed when this method is called.

=back

=head1 DIAGNOSTICS

This module throws an exception when it can't find any data files, when it can't
open a data file it found for reading or when a subroutine doesn't get enough arguments.
In the first case youn either don't have the freedesktop mime info database installed, 
or your environment variables point to the wrong places,
in the second case you have the database installed, but it is broken 
(the mime info database should logically be world readable).

=head1 TODO

Make an option for using some caching mechanism to reduce init time.

Make L</describe> do real xml parsing ?

=head1 BUGS

Perl versions prior to 5.8.0 do not have the ':utf8' IO Layer, thus
for the default method and for reading the xml files
utf8 is not supported for these versions.

Since it is not possible to distinguishe between encoding types (utf8, latin1, latin2 etc.)
in a straightforward manner only utf8 is supported (because the spec recommends this).

Please mail the author when you encounter any other bugs.

=head1 AUTHOR

Jaap Karssenberg || Pardus [Larus] E<lt>pardus@cpan.orgE<gt>

Copyright (c) 2003 Jaap G Karssenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<File::BaseDir>,
L<File::MimeInfo::Magic>,
L<File::MimeInfo::Rox>

=over 4

=item related CPAN modules

L<File::MMagic>

=item freedesktop specifications used

L<http://freedesktop.org/Standards/shared-mime-info-spec>,
L<http://freedesktop.org/Standards/basedir-spec>

=item freedesktop mime database

L<http://freedesktop.org/Software/shared-mime-info>

=item other programs using this mime system

L<http://rox.sourceforge.net>

=cut

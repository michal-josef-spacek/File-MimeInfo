package File::MimeInfo;

use strict;
use Carp;
use File::BaseDir qw/xdg_data_files/;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(mimetype);
our @EXPORT_OK = qw(describe globs inodetype);
our $VERSION = '0.6';
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
	binmode FILE, ':utf8' unless $] < 5.008;
	read FILE, $line, 10;
	close FILE;

	$line =~ s/\s//g; # \n and \t are also control chars
	return 'text/plain' unless $line =~ /[\x00-\x1F\xF7]/;
	print "> First 10 bytes of the file contain control chars\n" if $DEBUG;
	return 'application/octet-stream';
}

sub rehash {
	(@globs, %literal, %extension) = ((), (), ()); # clear data
	my $done;
	++$done && _hash_globs($_) for reverse xdg_data_files('mime/globs');
	print STDERR << 'EOE' unless $done;
You don't seem to have a mime-info database.
See http://www.freedesktop.org/software/shared-mime-info/
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
	my $mt = pop || croak 'subroutine "describe" needs a mimetype as argument';
	my $att =  $LANG ? qq{xml:lang="$LANG"} : '';
	my $desc;
	for my $file (xdg_data_files('mime', split '/', "$mt.xml")) {
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

Make Base Dir Spec stuff separate module ?

=head1 BUGS

Perl versions prior to 5.8.0 do not have the ':utf8' IO Layer, thus
for the default method and for reading the xml files
utf8 is not supported for these versions.

Please mail the author when you encounter any other bugs.

=head1 AUTHOR

Jaap Karssenberg || Pardus [Larus] E<lt>pardus@cpan.orgE<gt>

Copyright (c) 2003 Jaap G Karssenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<File::BaseDir>

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


use strict;

use Test::More tests => 27;

$ENV{XDG_DATA_HOME} = './t/';
$ENV{XDG_DATA_DIRS} = './t/'; # forceing non default value

use_ok('File::MimeInfo', qw/mimetype describe/); # 1

# test what was read
ok(scalar(keys %File::MimeInfo::extension) == 3, 'extension data is there');	# 2
ok(scalar(keys %File::MimeInfo::literal) == 1, 'literal data is there');	# 3
ok(scalar(@File::MimeInfo::globs) == 2, 'globs data is there');			# 4
# deze laatste heeft twee dezelfde entries :(

# test _glob_to_regexp
my $i = 0;
for (
	[ '*.pl',	'(?-xism:^.*\.pl$)'	],	# 5
	[ '*.h++',	'(?-xism:^.*\.h\+\+$)'	],	# 6
	[ '*.[tar].*',	'(?-xism:^.*\.[tar]\..*$)'],	# 7
	[ '*.?',	'(?-xism:^.*\..?$)'],		# 8
) { ok( File::MimeInfo::_glob_to_regexp($_->[0]) eq $_->[1], 'glob '.++$i ) }

# test parsing file names
$i = 0;
for (
	['script.pl', 'application/x-perl'],		# 9
	['script.old.pl', 'application/x-perl'],	# 10
	['script.PL', 'application/x-perl'],		# 11
	['script.tar.pl', 'application/x-perl'],	# 12
	['script.gz', 'application/x-gzip'],		# 13
	['script.tar.gz', 'application/x-compressed-tar'],	# 14
	['INSTALL', 'text/x-install'],			# 15
	['script.foo.bar.gz', 'application/x-gzip'],	# 16
	['script.foo.tar.gz', 'application/x-compressed-tar'],	# 17
	['makefile', 'text/x-makefile'],		# 18
) { ok( mimetype($_->[0]) eq $_->[1], 'file '.++$i ) }

# test OO interface
my $ref = File::MimeInfo->new ;
ok(ref($ref) eq q/File::MimeInfo/, 'constructor works'); # 19
ok( $ref->mimetype('script.pl') eq 'application/x-perl', 'OO syntax works'); # 20

# test default
ok( mimetype('t/default/binary_file') eq 'application/octet-stream', 'default works for binary data');	# 21
ok( mimetype('t/default/plain_text')  eq 'text/plain', 'default works for plain text');			# 22
ok( mimetype('t/default/empty_file')  eq 'text/plain', 'default works for empty file');			# 23
ok( ! defined mimetype('t/non_existing_file'), 'default works for non existing file');		# 24

# test inode thingy
ok( mimetype('t') eq 'inode/directory', 'directories are recognized'); # 25

# test describe
ok( describe('text/plain') eq 'Plain Text', 'describe works' ); # 26
$File::MimeInfo::LANG = 'nl';
ok( describe('text/plain') eq 'Platte tekst', 'describe works with other languages' ); # 27


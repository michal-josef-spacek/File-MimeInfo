
use strict;

use Test::More tests => 18;

@File::MimeInfo::DIRS = './t';

use_ok('File::MimeInfo');

# test what was read
ok(scalar(keys %File::MimeInfo::extension) == 3, 'extension data is there');
ok(scalar(keys %File::MimeInfo::literal) == 1, 'literal data is there');
ok(scalar(@File::MimeInfo::globs) == 1, 'globs data is there');

# test _glob_to_regexp
my $i = 0;
for (
	[ '*.pl',	'(?-xism:^.*\.pl$)'	],	# 1
	[ '*.h++',	'(?-xism:^.*\.h\+\+$)'	],	# 2
	[ '*.[tar].*',	'(?-xism:^.*\.[tar]\..*$)'],	# 3
	[ '*.?',	'(?-xism:^.*\..?$)'],		# 4
) { ok( File::MimeInfo::_glob_to_regexp($_->[0]) eq $_->[1], 'glob '.++$i ) }

# test parsing file names
$i = 0;
for (
	['script.pl', 'application/x-perl'],		# 1
	['script.old.pl', 'application/x-perl'],	# 2
	['script.PL', 'application/x-perl'],		# 3
	['script.tar.pl', 'application/x-perl'],	# 4
	['script.gz', 'application/x-gzip'],		# 5
	['script.tar.gz', 'application/x-compressed-tar'],	# 6
	['INSTALL', 'text/x-install'],			# 7
	['script.foo.bar.gz', 'application/x-gzip'],	# 8
	['script.foo.tar.gz', 'application/x-compressed-tar'],	# 9
	['makefile', 'text/x-makefile'],		# 10
) { ok( mimetype($_->[0]) eq $_->[1], 'file '.++$i ) }

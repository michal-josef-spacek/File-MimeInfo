require Test::More;

opendir MAGIC, 't/magic/';
my @files = grep {$_ !~ /\./ and $_ ne 'CVS'} readdir MAGIC;
closedir MAGIC;

Test::More->import( tests => (scalar(@files) + 1) );

use_ok('File::MimeInfo::Magic', qw/magic/);

for (@files) {
	$type = $_;
	$type =~ tr#_#/#;
	ok( magic("t/magic/$_") eq $type, "magic typing of $_" )
}

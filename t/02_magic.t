require Test::More;

no warnings;
@File::MimeInfo::DIRS = ('./t/mime'); # forceing non default value

opendir MAGIC, 't/magic/';
my @files = grep {$_ !~ /\./ and $_ ne 'CVS'} readdir MAGIC;
closedir MAGIC;

Test::More->import( tests => (scalar(@files) + 1) );

use_ok('File::MimeInfo::Magic', qw/mimetype magic/);

for (@files) {
	$type = $_;
	$type =~ tr#_#/#;
	ok( magic("t/magic/$_") eq $type, "magic typing of $_" )
}

require Test::More;

$ENV{XDG_DATA_HOME} = './t/';
$ENV{XDG_DATA_DIRS} = './t/'; # forceing non default value

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

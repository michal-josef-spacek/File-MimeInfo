
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'File::MimeInfo',
	'VERSION_FROM'	=> 'MimeInfo.pm',
	'PREREQ_PM'	=> {
		'Carp'		=> 0,
		'Exporter'	=> 0,
		'File::Spec'	=> 0,
		'Pod::Usage'	=> 0,
	},
	($] >= 5.005
    		? (AUTHOR => 'Jaap Karssenberg <pardus@cpan.org>')
		: ()
	),
	'EXE_FILES'	=> ['mimetype'],
);

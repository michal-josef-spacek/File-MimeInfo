
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'File::MimeInfo',
	'VERSION_FROM'	=> 'MimeInfo.pm',
	'PREREQ_PM'	=> {
		'Carp'		=> 0,
		'Exporter'	=> 0,
		'File::Spec'	=> 0,
	},
	($] >= 5.005
    		? (AUTHOR => 'Jaap Karssenberg <j.g.karssenberg@student.utwente.nl>')
		: ()
	),
);

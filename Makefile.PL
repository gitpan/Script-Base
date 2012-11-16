
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Bootstrap your scripts",
  "AUTHOR" => "Nour Sharabash <amirite\@cpan.org>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Script-Base",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Script::Base",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Class::Data::Inheritable" => 0,
    "Class::Exporter" => 0,
    "DBI" => 0,
    "DBIx::Simple" => 0,
    "Data::Dumper" => 0,
    "FindBin" => 0,
    "Getopt::Long" => 0,
    "IO::All" => 0,
    "IO::File" => 0,
    "Mojo::Base" => 0,
    "Pod::Usage" => 0,
    "Scalar::Util" => 0,
    "String::CamelCase" => 0,
    "YAML" => 0,
    "base" => 0,
    "mro" => 0
  },
  "VERSION" => "0.02",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);




# vim: ts=4 sw=4 noexpandtab
package Script::Config;
{
  $Script::Config::VERSION = '0.01';
}
use Mojo::Base -base;
use YAML qw/LoadFile DumpFile/;

sub new {
	my ( $class, %path ) = @_;
	my ( $self, %file ) = ( {} );

	bless $self, $class;

	if ( $path{base} ) {
		opendir my $dir, $path{base} or die "Couldn't open directory '$path{base}': $!";

		my %copy = map {
			$_ => "$path{base}/$_"
		  } grep {
			-d "$path{base}/$_" and $_ !~ /^\./
		  } readdir $dir;

		for ( grep { $_ ne 'base' } keys %copy ) {
			$path{ $_ } = $copy{ $_ } unless $path{ $_ };
		}

		closedir $dir;
	}

	if ( -d "$path{config}" ) {
		my $path = "$path{config}";
		opendir my $dir, $path or die "Couldn't open directory '$path': $!";
		push @{ $file{public} }, map { "$path/$_" } grep {
			-e "$path/$_" and $_ !~ /^\./ and $_ =~ /\.yml$/
		} readdir $dir;
		closedir $dir;
	}

	if ( -d "$path{config}/private" ) {
		my $path = "$path{config}/private";
		opendir my $dir, $path or die "Couldn't open directory '$path': $!";
		push @{ $file{private} }, map { "$path/$_" } grep {
			-e "$path/$_" and $_ !~ /^\./ and $_ =~ /\.yml$/
		} readdir $dir;
		closedir $dir;
	}

	for my $file ( @{ $file{public} } ) {
		my ( $name ) = ( split /\//, $file )[ -1 ] =~ /^(.*)\.yml$/;
		my $conf = LoadFile $file;

		if ( $name eq 'config' ) {
			$self->{ $_ } = $conf->{ $_ } for keys %{ $conf };
		}
		else {
			if ( exists $conf->{ $name } and scalar keys %{ $conf } == 1 ) {
				$self->{ $name } = $conf->{ $name };
			}
			else {
				$self->{ $name }->{ $_ } = $conf->{ $_ } for keys %{ $conf };
			}
		}
	}

	for my $file ( @{ $file{private} } ) {
		my ( $name ) = ( split /\//, $file )[ -1 ] =~ /^(.*)\.yml$/;
		my $conf = LoadFile $file;

		if ( $name eq 'config' ) {
			$self->{ "_$_" } = $conf->{ $_ } for keys %{ $conf };
		}
		else {
			if ( exists $conf->{ $name } and scalar keys %{ $conf } == 1 ) {
				$self->{ "_$name" } = $conf->{ $name };
			}
			else {
				$self->{ "_$name" }->{ $_ } = $conf->{ $_ } for keys %{ $conf };
			}
		}
	}

	$self->{__path} = \%path;

	return $self;
}

sub write {
	my ( $self ) = ( shift );
	my ( %public, %private );

	%public = map { $_ => $self->{ $_ } } grep { not $_ =~ /^_/ } keys %{ $self };
	%private = map { $_ => $self->{ $_ } } grep { $_ =~ /^_/ and not $_ =~ /^__/ } keys %{ $self };

	DumpFile( "$self->{__path}->{config}/config.yml",         \%public )  if %public;
	DumpFile( "$self->{__path}->{config}/private/config.yml", \%private ) if %private;
}

1;

# ABSTRACT: Config component for Script::Base

__END__

=pod

=head1 NAME

Script::Config - Config component for Script::Base

=head1 VERSION

version 0.01

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

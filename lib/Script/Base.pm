# vim: ts=4 sw=4 noexpandtab
package Script::Base;
{
  $Script::Base::VERSION = '0.01';
}
use Mojo::Base -base;
use base 'Class::Data::Inheritable';
use mro 'c3';
use Scalar::Util qw/isweak weaken/;
use String::CamelCase qw/camelize decamelize wordsplit/;
use Script::Database;
use Script::Printer;
use Script::Config;
use Getopt::Long;
use Pod::Usage;
use IO::All;
use FindBin;
use Carp; $Carp::Verbose = 1;
use DBI;

__PACKAGE__->mk_classdata( '__config' );

has '___config';
has __db => sub { {} };
has option => sub { {} };
has base => sub {
	my $self = shift;
	my $base;

	return $ENV{SCRIPT_BASE} if $ENV{SCRIPT_BASE};

	$base = $FindBin::Bin;
	$base =~ s/\/script\/?$//
		if $base =~ /\/script\/?$/ and ( -e "$base/../config" or -e "$base/../lib" );

	return $base;
};
has printer => sub {
	my $self = shift;
	my %opts = (
		timestamp => 1
		, verbose => 1
		, debug => 1
		, quiet => 0
		, pid => 1
		, %{ $self->option } #( $self->super and ref $self->super->option ) ? %{ $self->super->option } : ref $self->option ? %{ $self->option } : ()
	);


	my $printer = new Script::Printer (
		super => $self
		, %opts
	);
	
	return $printer;
};
has 'super';

sub _config {
	my $self = shift;
	my @path = map { decamelize( $_ ) } split /::/, ref $self;
	my $path = join '/', $self->base, qw/config/, @path;
	my $conf = new Script::Config ( config => $path );

	$self->___config( $conf );

	$self->merge( $self->__config, $conf );
	$self->merge( $conf, $self->__config );
}

sub new {
	my $self = shift->SUPER::new( @_ );
	my %conf = %{ $self };

	$self->__config( {} ) unless $self->__config;

	my ( $super );
	weaken( $super = delete $self->{super} ) if $self->{super};
	$self->super( $super ) if $super;

	$self->_config;
	$self->config( %conf ) if %conf;

	for my $key ( keys %{ $self->config } ) {
		if ( $self->can( $key ) ) {
			$self->$key( $self->config->{ $key } );
		}
	}


	$self->_build_option;

	$self->init;

	$self->{init} = 1;

	return $self;
}

sub init {
	my $self = shift;

	$self->info( 'init '. ref $self );

	$self->dump( 'option', $self->option ) if $self->option->{ 'dump-option' };
	$self->dump( 'config', $self->config ) if $self->option->{ 'dump-config' };

	return $self;
}

sub config {
	my $self = shift;
	my $args = scalar @_;

	$self->__config( {} ) unless $self->__config;

	if ( $args ) {
		return $self->__config->{ $_[0] } if $args == 1 and not ref $_[0];

		my %config = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

		for my $key ( keys %config ) {
			$self->__config->{ $key } = $config{ $key };
			if ( $self->___config ) {
				$self->___config->{ $key } = $config{ $key };
			}

			if ( $self->can( $key ) ) {
				$self->$key( $config{ $key } );
			}
		}
	}

	return $self->__config;
}

sub path {
	my ( $self, @path ) = @_;
	return $self->base . join '/', @path;
}

sub _build_option {
	my $self = shift;
	my %option;

	$self->merge( \%option, $self->config->{option}->{defaults} ) if $self->config->{option}->{defaults};
	$self->merge( \%option, $self->super->option ) if $self->super and $self->super->option;

	GetOptions( \%option
		, qw/dump-option|do dump-config|dc timestamp! verbose! debug! quiet! pid! help/
		, $self->config->{option}->{options} ? @{ $self->config->{option}->{options} } : ()
	) or pod2usage( 1 );

	pod2usage( 1 ) if $option{help};

	$self->option( \%option );
}

sub db {
	my ( $self, $dbc ) = @_;

	$dbc ||= 'default';

	return $self->__db->{ $dbc } if $self->__db->{ $dbc };
	return $self->__db->{ $dbc } if $self->connect_db( $dbc );
}

sub connect_db { # TODO: put this in Script::Database
	my ( $self, $dbc, $try ) = @_;

	$dbc ||= 'default';
	$try ||= 1;

	$self->verbose( "connecting to $dbc database...". ( $try > 1 ? " try #$try" : '' ) );

	my ( %config, %dbc, @dbc, $dbh );

	$self->merge( \%config, new Script::Config (
		config => $self->base .'/config/script/database'
	) );

	$self->merge( \%config, $self->config->{database} )
		if $self->config->{database};

	%dbc = %{ $config{connection} };

	$self->merge( \%dbc, $config{_connection} ) # private config override for sensitive stuff, e.g. ./config/script/database/private/config.yml
		if $config{_connection};

	for my $dbc ( keys %dbc ) {
		$dbc{ $dbc }->{__save} = delete $dbc{ $dbc };
		$self->merge( $dbc{ $dbc }, $config{fallback} );
		$self->merge( $dbc{ $dbc }, delete $dbc{ $dbc }->{__save} );
		$self->dump( $dbc, \%dbc );
	}

	push @dbc, (
		$dbc{ $dbc }->{dsn}
		, $dbc{ $dbc }->{username}
		, $dbc{ $dbc }->{password}
		, $dbc{ $dbc }->{option} ? $dbc{ $dbc }->{option} : $config{connection_fallback}->{option} ? $config{connection_fallback}->{option} : {}
	);

	eval {
		$dbh = DBI->connect_cached( @dbc );
	};

	$self->error( "problem connecting to database $dbc: ", $@ ) if $@;

	unless ( $dbh ) {
		$self->error( "could not connect to database $dbc: " . $dbh->errstr );

		return 0 if $try >= 10;

		sleep $try;
		return $self->connect_db( $dbc, ++$try );
	}

	$self->__db->{ $dbc } = new Script::Database ( dbh => $dbh, super => $self );

	return 1;
}

#<
sub verbose { my $self = shift; ( $self->super and $self->super->can( 'verbose' ) ) ? $self->super->verbose( @_ )    : $self->printer->verbose( @_ ); }
sub debug   { my $self = shift; ( $self->super and $self->super->can( 'debug' ) )   ? $self->super->debug( @_ )      : $self->printer->debug( @_ );   }
sub test    { my $self = shift; ( $self->super and $self->super->can( 'test' ) )    ? $self->super->test( @_ )       : $self->printer->test( @_ );    }
sub info    { my $self = shift; ( $self->super and $self->super->can( 'info' ) )    ? $self->super->info( @_ )       : $self->printer->info( @_ );    }
sub warn    { my $self = shift; ( $self->super and $self->super->can( 'warn' ) )    ? $self->super->warn( @_ )       : $self->printer->warn( @_ );    }
sub warning { my $self = shift; ( $self->super and $self->super->can( 'warning' ) ) ? $self->super->warning( @_ )    : $self->printer->warn( @_ );    }
sub error   { my $self = shift; ( $self->super and $self->super->can( 'error' ) )   ? $self->super->error( @_ )      : $self->printer->error( @_ );   }
sub fatal   { my $self = shift; ( $self->super and $self->super->can( 'fatal' ) )   ? $self->super->fatal( @_ )      : $self->printer->fatal( @_ );   }
sub dump    { my $self = shift; ( $self->super and $self->super->can( 'dump' ) )    ? $self->super->dump( @_ )       : $self->printer->dump( @_ );    }
sub dumper  { my $self = shift; ( $self->super and $self->super->can( 'dumper' ) )  ? $self->super->dumper( @_ )     : $self->printer->dumper( @_ );  }
#>

sub write { shift->___config->write }

sub merge {
	my $self = shift;
	my ( $ref_1, $ref_2 ) = @_;
	for my $key ( keys %{ $ref_2 } ) {
		if ( defined $ref_1->{ $key } ) {
			if ( ref $ref_1->{ $key } eq 'HASH' and ref $ref_2->{ $key } eq 'HASH' ) {
				$self->merge( $ref_1->{ $key }, $ref_2->{ $key } );
			}
			else {
				$ref_1->{ $key } = $ref_2->{ $key };
			}
		}
		else {
			if ( ref $ref_2->{ $key } eq 'HASH' ) {
				my %ref_2_key = %{ $ref_2->{ $key } };
				$ref_1->{ $key } = \%ref_2_key;
			}
			else {
				$ref_1->{ $key } = $ref_2->{ $key };
			}
		}
	}
}

sub sys_cmd {
	my ( $self, @args ) = @_;

	$self->info( join ' ', @args );

	my $code = system( @args );

	$self->fatal( "system command exited with non-zero status code: $_" ) unless $code == 0;
}

sub io_all {
	my ( $self, @args ) = @_;
	return io( @args );
}

1;

# ABSTRACT: Bootstrap your scripts

__END__

=pod

=head1 NAME

Script::Base - Bootstrap your scripts

=head1 VERSION

version 0.01

=head1 SYNOPSIS

=head2 Package Example

=head2 Script Usage

=head1 DESCRIPTION

=head1 NAME

Script::Base

=head1 SEE ALSO

=head1 AUTHOR

Nour Sharabash <F<amirite@cpan.org>>

=head1 COPYRIGHT AND DISCLAIMER

This program is Copyright 2012 by Nour Sharabash.

This program is free software; you can redistribute it and/or
modify it under the terms of the Perl Artistic License or the
GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

If you do not have a copy of the GNU General Public License write to
the Free Software Foundation, Inc., 675 Mass Ave, Cambridge,
MA 02139, USA.

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

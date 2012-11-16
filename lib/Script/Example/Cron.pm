package Script::Example::Cron;
{
  $Script::Example::Cron::VERSION = '0.02';
}
use Mojo::Base 'Script::Base';

#<
has stuff => sub { {} };
#>

sub init {
	my $self = shift->next::method( @_ );

	# do stuff
	if ( $self->option->{jump} ) {
		$self->info( 'jump!' ) for 1 .. $self->option->{count};
	}

	$self->fatal( "i want to --fly" ) unless $self->option->{fly};

	return $self;
}

sub run {
	my ( $self, %args ) = @_;
	my ( %opts, $other, $stuff ) = ( %{ $self->option } );

	$self->verbose( 'i prefer to fly' );

	$self->sys_cmd( qw/ls -las/ );

	my @blargh = $self->db->query( qq|
		select * from blargh
	| )->hashes;

	my $blah = $self->db( 'cron' )->query( qq|
		select count(*) from jobs
	| )->list;
}

1;

# ABSTRACT: Example Script Package for Script::Base

__END__

=pod

=head1 NAME

Script::Example::Cron - Example Script Package for Script::Base

=head1 VERSION

version 0.02

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

# vim: ts=4 sw=4 noexpandtab
package Script::Printer;
{
  $Script::Printer::VERSION = '0.01';
}
use Mojo::Base 'Script::Base';
use base 'Class::Exporter';
use IO::File;
use Data::Dumper;
our @EXPORT_OK = qw/info test warning error fatal verbose debug dump dumper/;

BEGIN {
	$| = 1;
	autoflush STDOUT 1;
	autoflush STDERR 1;
}

sub init {
	my $self = shift->next::method( @_ );

	$self->option->{ $_ } = $self->{ $_ } for qw/timestamp verbose debug quiet pid/;

	return $self;
}

sub verbose {
	my $self = shift;
	return if $self->option->{quiet};
	return unless $self->{init} and $self->option->{verbose};
	
	print STDOUT $self->_prefix . '[verbose] ', join ( "\n[verbose] ", @_ ), "\n";
}

sub debug {
	my $self = shift;
	return if $self->option->{quiet};
	return unless $self->{init} and $self->option->{debug};
	$self->dump( 'option', $self->option );
	print STDOUT $self->_prefix . '[debug] ', join ( "\n[debug] ", @_ ), "\n";
}

sub test {
	my $self = shift;
	return if $self->option->{quiet};
	print STDERR $self->_prefix . '[test] ', join ( "\n[test] ", @_ ), "\n";
}

sub info {
	my $self = shift;
	return if $self->option->{quiet};
	print STDOUT $self->_prefix . '[info] ', join ( "\n[info] ", @_ ), "\n";
}

sub warn {
	my $self = shift;
	return if $self->option->{quiet};
	print STDERR $self->_prefix . '[warning] ', join ( "\n[warning] ", @_ ), "\n";
}

sub warning { shift->warn( @_ ) }

sub error {
	my $self = shift;
	return $self->fatal( @_ ) if $self->option->{debug};
	print STDERR $self->_prefix . '[error] ', join ( "\n[error] ", @_ ), "\n";
}

sub fatal {
	my $self = shift;
	die $self->_prefix . '[fatal] ' . join ( "\n[fatal] ", @_ ) . "\n";
}

sub dump {
	my $self = shift;
	return if $self->option->{quiet};
	print STDERR $self->_prefix . ( ref $_ ? "[dump]\n". Dumper( $_ ) : "[dump] $_\n" ) for @_;
}

sub dumper { shift->dump( @_ ) }

sub _prefix {
	my $self = shift;
	my @s;
	push @s, $$ if $self->option->{pid};
	if ( $self->option->{timestamp} ) {
		my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime ( time );
		push @s, sprintf ( "%04d-%02d-%02d %02d:%02d:%02d", 1900 + $year, 1 + $mon, $mday, $hour, $min, $sec );
	}
	@s ? '[' . join ( ' ', @s ) . '] ' : '';
}

1;

# ABSTRACT: Printer component for Script::Base

__END__

=pod

=head1 NAME

Script::Printer - Printer component for Script::Base

=head1 VERSION

version 0.01

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

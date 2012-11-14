# vim: ts=4 sw=4 noexpandtab
package Script::Database;
{
  $Script::Database::VERSION = '0.01';
}
use Mojo::Base 'Script::Base';
use DBIx::Simple;

has 'dbh';
has 'dbq';
has 'dbx';

sub new {
	my $self = shift->next::method( @_ );
	my $dbh = delete $self->{dbh};

	die "need a database handle" unless $dbh;

	my $dbq = $dbh;
	my $dbx = $dbh->clone;

	$dbx->{AutoCommit} = 0;

	$self->dbh( $dbh );
	$self->dbq( new DBIx::Simple ( $dbq ) );
	$self->dbx( new DBIx::Simple ( $dbx ) );

	return $self;
}

sub AUTOLOAD {
	my $self = shift;
	( my $method = $Script::Database::AUTOLOAD ) =~ s/^.*://;
	return $self->dbq->$method( @_ ) if $self->dbq and $self->dbq->can( $method );
	return $self->dbh->$method( @_ ) if $self->dbh and $self->dbh->can( $method );
}

sub select {
	my ( $self, @args ) = @_;
	my ( %opts, $res, @res, $ret );

	%opts = %{ pop @args }
		if ref $args[-1] eq 'HASH' and $args[-1]->{return};

	unless ( ref $args[-1] eq 'HASH' ) {
		$res = $self->dbq->query( @args );
	}
	else {
		$res = $self->dbq->select( @args );
	}

	$ret = $opts{return};
	return $res->$ret if $ret;

	( @res ) = wantarray ? $res->flat : $res->hashes;
	return wantarray ? @res : \@res;
}

sub insert {
	my ( $self, $rel, $rec ) = ( shift, shift, shift );
	my %opts = ref $_[-1] eq 'HASH' ? %{ $_[-1] } : @_;
	my @vals = map { $rec->{ $_ } } sort keys %{ $rec };
	my $cols = join ', ', sort keys %{ $rec };
	my $hold = join ', ', map { '?' } sort keys %{ $rec };
	my $crud = $opts{replace} ? 'replace' : $opts{ignore} ? 'insert ignore' : 'insert';
	my ( $sql, @bind ) = $self->dbx->query( qq|
		$crud into $rel ( $cols ) values ( $hold )
	|, @vals );
	my $insert_id = $self->insert_id( $rel, $rec );

	$self->debug( "inserted into $rel". ( $insert_id ? " ( $insert_id )" : '' ) );

	return $insert_id;
}

sub insert_id {
	my ( $self, $rel, $rec ) = @_;

	# wrap with if ( mysql )
	my $db = $self->dbh->{Name};
	   $db =~ s/^database=([^;].*);host.*$/$1/;

	return $self->dbx->last_insert_id( qw/information_schema/, $db, $rel, $rel .'_id' );
}

sub update {
	my ( $self, $rel, $rec, $cond ) = @_;
	return unless ref $cond eq 'HASH';
	my $result = $self->dbx->update( $rel, $rec, $cond );
	$self->debug( "updated $rel" );
	return $result;
}

sub delete {
	my ( $self, $rel, $cond ) = @_;
	return unless ref $cond eq 'HASH';
	my $result = $self->dbx->delete( $rel, $cond );
	$self->debug( "deleted from $rel" );
	return $result;
}

sub commit {
	my $self = shift;

	$self->dbx->commit;
	$self->debug( 'commit' );
}

1;

# ABSTRACT: Database component for Script::Base

__END__

=pod

=head1 NAME

Script::Database - Database component for Script::Base

=head1 VERSION

version 0.01

=head1 AUTHOR

Nour Sharabash <amirite@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Nour Sharabash.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

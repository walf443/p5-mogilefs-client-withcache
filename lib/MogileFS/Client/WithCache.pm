package MogileFS::Client::WithCache;

use strict;
use warnings;
use base qw/ MogileFS::Client /;
use fields (
            'cache',
            'cache_expire',
            'namespace',
            );

use Carp;
our $VERSION = '0.01';

sub new {
    my (undef, %args) = @_;
    my $self = __PACKAGE__->SUPER::new(%args);

    $self->{cache} = $args{cache}
        or croak('MogileFS::Client::WithCache: cache should be required');
    $self->{cache_expire} = $args{cache_expire}
        or croak('MogileFS::Client::WithCache: cache_expire should be required');
    $self->{namespace} = ( $args{namespace} ||  __PACKAGE__ );

    return $self;
}

sub store_file {
    my $self = shift;
    my ($key, $class, $file, $opts ) = @_;
    my $result = $self->SUPER::store_file(@_);
    $self->{cache}->delete($key);
    return $result;
}

sub store_content {
    my $self = shift;
    my ($key, $class, $file, $opts ) = @_;
    my $result = $self->SUPER::store_content(@_);
    $self->{cache}->delete($key);
    return $result;
}

sub get_paths {
    my ($self, $key, $opts) = @_;

    my $cache_key = $self->{namespace} . "_" . $key;
    my $result = $self->{cache}->get($cache_key);

    unless ( defined $result ) {
        $result = join q{ }, $self->get_paths_without_cache($key, $opts);
        $self->{cache}->set($cache_key => $result, $self->{cache_expire});
    }

    return ( split q{ }, $result );
}

sub get_paths_without_cache {
    my $self = shift;
    return ( $self->SUPER::get_paths(@_) );
}

sub delete {
    my ($self, $key) = @_;
    my $result = $self->SUPER::delete($key);
    $self->{cache}->delete($key);
    return $result;
}

sub rename {
    my ($self, $fkey, $tkey) = @_;
    my $result = $self->SUPER::remane($fkey, $tkey);
    $self->{cache}->delete($fkey);
    return $result;
}

1;
__END__

=head1 NAME

MogileFS::Client::WithCache -

=head1 SYNOPSIS

  use MogileFS::Client::WithCache;

=head1 DESCRIPTION

MogileFS::Client::WithCache is

=head1 AUTHOR

Keiji Yoshimi E<lt>walf443@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

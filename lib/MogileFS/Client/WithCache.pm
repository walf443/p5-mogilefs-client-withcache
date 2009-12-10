package MogileFS::Client::WithCache;

use strict;
use warnings;
use base qw/ MogileFS::Client /;
use Carp;
our $VERSION = '0.01';

sub new {
    my (undef, %args) = @_;
    my $self = __PACKAGE__::SUPER::new(@_);

    $self->{cache} = $args{cache}
        or croak('MogileFS::Client::WithCache: cache should be required');
    $self->{cache_expire} = $args{cache_expire}
        or croak('MogileFS::Client::WithCache: cache_expire should be required');

    return $self;
}

sub store_file {
    my ($self, $key, $class, $file, $opts ) = @_;
    my $result = SUPER::store_file(@_);
    $self->{cache}->delete($key);
    return $result;
}

sub store_content {
    my ($self, $key, $class, $file, $opts ) = @_;
    my $result = SUPER::store_content(@_);
    $self->{cache}->delete($key);
    return $result;
}

sub get_paths {
    my ($self, $key, $opts) = @_;

    my $result = $self->{cache}->get($key);
    unless ( defined $result ) {
        $result = $self->get_paths_without_cache($key, $opts);
        $self->{cache}->set($key);
    }
}

sub get_paths_without_cache {
    SUPER::get_paths(@_);
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

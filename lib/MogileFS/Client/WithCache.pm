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
    $self->_cache_clear($key);
    return $result;
}

sub store_content {
    my $self = shift;
    my ($key, $class, $file, $opts ) = @_;
    my $result = $self->SUPER::store_content(@_);
    $self->_cache_clear($key);
    return $result;
}

sub get_paths {
    my ($self, $key, $opts) = @_;

    my $cache_key = $self->_get_cache_key($key);
    my $result = $self->{cache}->get($cache_key);

    unless ( defined $result ) {
        $result = join q{ }, $self->get_paths_without_cache($key, $opts);
        $self->{cache}->set($cache_key => $result, $self->{cache_expire});
    }

    return ( split q{ }, $result );
}

sub _get_cache_key {
    my ($self, $key ) = @_;
    return $self->{namespace} . "_" . $key;
}

sub _cache_clear {
    my ($self, $key) = @_;
    $self->{cache}->delete($self->_get_cache_key($key));
}

sub get_paths_without_cache {
    my $self = shift;
    return ( $self->SUPER::get_paths(@_) );
}

sub delete {
    my ($self, $key) = @_;
    my $result = $self->SUPER::delete($key);
    $self->_cache_clear($key);
    return $result;
}

sub rename {
    my ($self, $fkey, $tkey) = @_;
    my $result = $self->SUPER::remane($fkey, $tkey);
    $self->_cache_clear($fkey);
    return $result;
}

1;
__END__

=head1 NAME

MogileFS::Client::WithCache -

=head1 SYNOPSIS

  use MogileFS::Client::WithCache;
  use Cache::Memcached::Fast;
  my $cache = Cache::Memcached::Fast->new(
    servers => ['10.0.0.1:11211'],
    namespace => 'my_namespace',
  );
  my $mogilefs = MogileFS::Client::WithCache->new(
    domain  => 'foo.com::my_namespace',
    hosts   => ['10.0.0.2:7001', '10.0.0.3:7001'],
    cache   => $cache,
    namespace => 'my_namespace_mogile',
    cache_expire => 5 * 60, # 5 min.
  );

  # get with cache
  my @paths = $mogilefs->get_paths('some_key'); 

  # update and clear cache.
  $mogilefs->store_content('some_key', 'some_class', 'content');

  # get_paths without caching.
  my @paths2 = $mogilefs->get_paths_without_cache('some_key');

=head1 DESCRIPTION

MogileFS::Client::WithCache is for caching get_paths's call automatically.

I know memcached backend for MogileFS, but I want to cache by application layer.

Don't cache too long for rebalance or move files. It's limit of application layer caching.

=head1 AUTHOR

Keiji Yoshimi E<lt>walf443@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

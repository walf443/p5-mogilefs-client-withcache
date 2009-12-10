package MogileFS::MockBackend;
use strict;
use warnings;
use base qw/MogileFS::Backend/;

sub new {
    my $self = {};
    bless $self, __PACKAGE__;
    return $self;
}

sub do_request {
    my ($self, $cmd, $opt ) = @_;
    if ( $cmd eq 'get_paths' ) {
        my $domain = $opt->{domain};
        my $key = $opt->{key};
        return $self->{expect_of}->{get_paths}->{$domain}->{$key};
    }
}

sub set_expect_for_request {
    my ($self, $cmd, $opt, $val) = @_;
    $self->{expect_of} ||= {};
    if ( $cmd eq 'get_paths' ) {
        my $domain = $opt->{domain};
        my $key = $opt->{key};
        $self->{expect_of}->{get_paths} ||= {};
        $self->{expect_of}->{get_paths}->{$domain} ||= {};
        $self->{expect_of}->{get_paths}->{$domain}->{$key} = $val;
    }
}

sub reload {
}

sub last_tracker {
}

sub errstr {
}

sub errcode {
}

package Cache::Stub;
use strict;
use warnings;

sub new {
    my $self = {};
    bless $self, __PACKAGE__;
    return $self;
}

sub get {
    my ($self, $key) = @_;

    $self->{__get_count} ||= {};
    $self->{__get_count}->{$key}++;
    $self->{__last_get_key} = $key;
    $self->{__cache} ||= {};
    return $self->{__cache}->{$key};
}

sub get_count {
    return ( $_[0]->{__get_count}->{$_[1]} || 0 );
}

sub get_count_clear {
    $_[0]->{__get_count} = {};
}

sub last_get_key {
    $_[0]->{__last_get_key};
}

sub set {
    my ($self, $key, $val, $expire) = @_;
    $self->{__last_set} = [ $key, $val, $expire ];
    $self->{__cache} ||= {};
    $self->{__cache}->{$key} = $val;
}

sub last_set {
    $_[0]->{__last_set};
}

sub delete {
    my ($self, $key) = @_;
    $self->{__cache} ||= {};
    $self->{__last_delete_key} = $key;
    delete $self->{__cache}->{$key};
}

sub last_delete_key {
    $_[0]->{__last_delete_key};
}

package main;
use strict;
use warnings;
use Test::More;
use MogileFS::Client;
use MogileFS::Client::WithCache;
use Data::Dumper;
use File::Temp;

my $code = sub {
    my ($self,  %args) = @_;

    $self->{backend} = MogileFS::MockBackend->new;
    $self->{domain} = $args{domain};
    return $self;
};

{
    no strict 'refs';
    no warnings 'redefine';
    *{"MogileFS::Client::_init"} = $code;
}

# ----------------------------------------------------------
# direct
{
    my $cache = Cache::Stub->new;
    my $domain = 'app';
    my $cache_expire = 5 * 60;
    my $mogilefs = MogileFS::Client::WithCache->new(
        domain => $domain,
        hosts   => ['10.0.0.2:7001', '10.0.0.3:7001'],
        cache   => $cache,
        namespace => 'my_namespace_mogile',
        cache_expire => $cache_expire,
    );
    
    my $key = 'foo';
    
    is($mogilefs->_get_cache_key($key), 'my_namespace_mogile_foo', '_cache_key');
    $mogilefs->{backend}->set_expect_for_request('get_paths', {
        domain => $domain,
        key    => $key,
    }, {
            paths => 3,
            path1 => 'http://localhost/000001.fid',
            path2 => 'http://localhost/000002.fid',
            path3 => 'http://localhost/000003.fid',
    });
    
    my @paths = $mogilefs->get_paths_without_cache($key);
    
    is_deeply(\@paths, [qw| 
        http://localhost/000001.fid
        http://localhost/000002.fid
        http://localhost/000003.fid
    |], 'get_paths_without_cache ok')
        or diag(Dumper(\@paths));

    is($cache->get_count('my_namespace_mogile_foo'), 0, 'cache should not be used');

    $mogilefs->get_paths($key);
    $mogilefs->get_paths($key);
    # this set should not be affected.
    $mogilefs->{backend}->set_expect_for_request('get_paths', {
        domain => $domain,
        key    => $key,
    }, {
            paths => 3,
            path1 => 'http://localhost/000004.fid',
            path2 => 'http://localhost/000005.fid',
            path3 => 'http://localhost/000006.fid',
    });
    
    my @paths2 = $mogilefs->get_paths($key);
    is_deeply(\@paths2, [qw| 
        http://localhost/000001.fid
        http://localhost/000002.fid
        http://localhost/000003.fid
    |], 'get_paths ok')
        or diag(Dumper(\@paths2));

    is_deeply($cache->last_set, ['my_namespace_mogile_foo', 'http://localhost/000001.fid http://localhost/000002.fid http://localhost/000003.fid', $cache_expire ], 'cache should be set');
    is($cache->get_count('my_namespace_mogile_foo'), 3, 'cache should be used');

    $cache->delete('my_namespace_mogile_foo');
    my @paths3 = $mogilefs->get_paths($key);
    is_deeply(\@paths3, [qw| 
        http://localhost/000004.fid
        http://localhost/000005.fid
        http://localhost/000006.fid
    |], 'get_paths ok')
        or diag(Dumper(\@paths3));

    is_deeply($cache->last_set, ['my_namespace_mogile_foo', 'http://localhost/000004.fid http://localhost/000005.fid http://localhost/000006.fid', $cache_expire ], 'cache should be set');
    is($cache->get_count('my_namespace_mogile_foo'), 4, 'cache should be used');

}

# ----------------------------------------------------------
# get_file_data
{
    my $cache = Cache::Stub->new;
    my $domain = 'app';
    my $cache_expire = 5 * 60;
    my $mogilefs = MogileFS::Client::WithCache->new(
        domain => $domain,
        hosts   => ['10.0.0.2:7001', '10.0.0.3:7001'],
        cache   => $cache,
        namespace => 'my_namespace_mogile',
        cache_expire => $cache_expire,
    );
    
    my $key = 'foo';

    my ($fh, $filename) = File::Temp::tempfile();
    print $fh "this is test\n";
    close $fh;
    $mogilefs->{backend}->set_expect_for_request('get_paths', {
        domain => $domain,
        key    => $key,
    }, {
            paths => 2,
            path1 => $filename,
            path2 => $filename,
    });

    my $content = $mogilefs->get_file_data($key);
    is($$content, "this is test\n", 'get_file_data should be success');
    is($cache->get_count('my_namespace_mogile_foo'), 1, 'cache should be used');

}

# ----------------------------------------------------------
# store_content
{
    my $cache = Cache::Stub->new;
    my $domain = 'app';
    my $cache_expire = 5 * 60;
    my $mogilefs = MogileFS::Client::WithCache->new(
        domain => $domain,
        hosts   => ['10.0.0.2:7001', '10.0.0.3:7001'],
        cache   => $cache,
        namespace => 'my_namespace_mogile',
        cache_expire => $cache_expire,
    );
    
    my $key = 'foo';

    $mogilefs->{backend}->set_expect_for_request('get_paths', {
        domain => $domain,
        key    => $key,
    }, {
            paths => 3,
            path1 => 'http://localhost/000001.fid',
            path2 => 'http://localhost/000002.fid',
            path3 => 'http://localhost/000003.fid',
    });
    
    my @paths = $mogilefs->get_paths($key);
    
    is_deeply(\@paths, [qw| 
        http://localhost/000001.fid
        http://localhost/000002.fid
        http://localhost/000003.fid
    |], 'get_paths_without_cache ok')
        or diag(Dumper(\@paths));

    is_deeply($cache->last_set, ['my_namespace_mogile_foo', 'http://localhost/000001.fid http://localhost/000002.fid http://localhost/000003.fid', $cache_expire ], 'cache should be set');
    $mogilefs->store_content($key, 'class', "this is file");
    is($cache->get('my_namespace_mogile_foo'), undef, 'cache should be deleted');

}

# ----------------------------------------------------------
# store_file
{
    my $cache = Cache::Stub->new;
    my $domain = 'app';
    my $cache_expire = 5 * 60;
    my $mogilefs = MogileFS::Client::WithCache->new(
        domain => $domain,
        hosts   => ['10.0.0.2:7001', '10.0.0.3:7001'],
        cache   => $cache,
        namespace => 'my_namespace_mogile',
        cache_expire => $cache_expire,
    );
    
    my $key = 'foo';

    $mogilefs->{backend}->set_expect_for_request('get_paths', {
        domain => $domain,
        key    => $key,
    }, {
            paths => 3,
            path1 => 'http://localhost/000001.fid',
            path2 => 'http://localhost/000002.fid',
            path3 => 'http://localhost/000003.fid',
    });
    
    my @paths = $mogilefs->get_paths($key);
    
    is_deeply(\@paths, [qw| 
        http://localhost/000001.fid
        http://localhost/000002.fid
        http://localhost/000003.fid
    |], 'get_paths_without_cache ok')
        or diag(Dumper(\@paths));

    is_deeply($cache->last_set, ['my_namespace_mogile_foo', 'http://localhost/000001.fid http://localhost/000002.fid http://localhost/000003.fid', $cache_expire ], 'cache should be set');
    my ($fh, $tempfile) = File::Temp::tempfile();
    print $fh "this is test\n";
    close $fh;
    $mogilefs->store_file($key, 'class', $tempfile);
    is($cache->get('my_namespace_mogile_foo'), undef, 'cache should be deleted');

}

done_testing();


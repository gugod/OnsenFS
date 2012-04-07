# -*- perl -*-
use v5.14;
use Test::More;

use OnsenFS::Remote;

my $remote = OnsenFS::Remote->new(
    access_key  => $ENV{EC2_ACCESS_KEY},
    secret_key  => $ENV{EC2_SECRET_KEY},
    bucket_name => $ENV{TEST_ONSENFS_REMOTE_BUCKET}
);

can_ok $remote, "set_key", "get_key", "head_key", "delete_key", "list_all";

done_testing;

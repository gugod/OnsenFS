# -*- perl -*-
use v5.14;

use OnsenFS::Local;
use File::Path::Tiny;
use Path::Class;
use Digest::SHA1 qw(sha1_hex);
use Digest::MD5 qw(md5_hex);
use Test::More;

my $local_dir = file(__FILE__)->dir->subdir("onsenfs-local-t");

File::Path::Tiny::mk($local_dir);

my $local = OnsenFS::Local->new(root => $local_dir);
my $object_dir  = $local_dir->subdir("objects");

subtest "`objects` directory is created" => sub {
    ok -d "$local_dir";
};

subtest "`add_key` methods creates objects files" => sub {
    my ($k, $v) = ("/foo/bar.txt", "The content of bar.");
    $local->add_key($k, $v, { content_type => "text/plain" });

    my $digest = sha1_hex($k);

    my $object_files = {
        body => $object_dir->file( "${digest}.body" ),
        meta => $object_dir->file( "${digest}.meta" ),
        name => $object_dir->file( "${digest}.name" ),
        etag => $object_dir->file( "${digest}.etag" )
    };

    ok -d "$object_dir";
    for (values %$object_files) { ok -f $_, "$_ exists"; }
};

subtest "`add_key` method does not create .body/.etag file when value is undef" => sub {
    my ($k, $v) = ("/foo/.txt", undef);
    $local->add_key($k, $v, { content_type => "text/plain" });

    my $digest = sha1_hex($k);

    my $object_files = {
        body => $object_dir->file( "${digest}.body" ),
        meta => $object_dir->file( "${digest}.meta" ),
        name => $object_dir->file( "${digest}.name" ),
        etag => $object_dir->file( "${digest}.etag" )
    };

    ok -d "$object_dir";
    ok -f $object_files->{name};
    ok -f $object_files->{meta};
    ok !-f $object_files->{body};
    ok !-f $object_files->{etag};
};

subtest "`add_key_filename` method" => sub {
    my $fn = dir($ENV{TMPDIR}||"/tmp")->file("/onsenfstest_$$");
    my $fh = $fn->openw;
    print $fh "Nihao\n";
    close($fh);

    $local->add_key_filename("/foo/nihao.txt", "$fn");
    my $digest = sha1_hex("/foo/nihao.txt");

    ok -f $object_dir->file("$digest.body");
    is $object_dir->file("$digest.body")->slurp, "Nihao\n";
};

subtest "`get_key` returns a hashref" => sub {
    my ($k, $v) = ("/foo/bar.txt", "The content of bar.");

    my $obj = $local->get_key($k);
    is ref($obj), "HASH";
    is $obj->{value}, $v, "value";
    is_deeply $obj->{content_type}, "text/plain","content-type";
    is $obj->{etag}, md5_hex($v), "etag";
};

subtest "`list_all_keys` returns an list of filenames" => sub {
    my @keys = $local->list_all_keys;

    for (@keys) {
        ok "go", $_;
    }
};


done_testing;

File::Path::Tiny::rm($local_dir);

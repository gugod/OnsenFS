use v5.14;
package OnsenFS::Local;

=head1 DESCRIPTION

OnsenFS::Local is a class that looks like an S3 bucket. While it can
store/fetch/list objects like a Net::Amazon::S3::Bucket class, it does not store
objects like a normal file system.

The purpose for this class is to let both OnsenFS::Fuse and OnsenFS::Synchronizer
instances to reuse. OnsenFS::Fuse only access through OnsenFS::Local, and the
Synchronizer observe the changes on Local and replicate the changes to S3 server.

=cut


use Moose;
use methods-invoker;

use Path::Class;
use File::Path::Tiny;
use Digest::SHA1 qw(sha1_hex);
use Digest::MD5 qw(md5_hex);
use JSON;
use File::Copy;

has root => (
    is => "ro",
    isa => "Path::Class::Dir",
    required => 1
);

method BUILD {
    my $odir = $self->root->subdir("objects");

    unless (-d $odir) {
        File::Path::Tiny::mk("$odir");
    }
}

method add_key($key, $value, $meta) {
    $meta = {} unless defined $meta;

    my $digest = sha1_hex($key);

    my $od = $self->root->subdir("objects");

    for my $x (
        [name => $key],
        [meta => encode_json($meta)],
        defined($value) ?
        (
            [etag => md5_hex($value)],
            [body => $value]
        ) : ()
    ) {
        my $ofh = $od->file("${digest}." . $x->[0])->openw;
        print $ofh $x->[1];
        close $ofh;
    }
}

func link_or_copy($oldfile, $newfile) {
    return 1 if link($oldfile, $newfile);
    return 1 if copy($oldfile, $newfile);
    return 0;
}

method add_key_filename($key, $filename, $meta) {
    utf8::encode($key) if utf8::is_utf8($key);

    $meta = {} unless defined $meta;

    my $digest = sha1_hex($key);

    my $md5 = Digest::MD5->new;

    link_or_copy($filename, $self->body_file($key)->stringify);

    my $od = $self->root->subdir("objects");

    $md5->addfile( $self->body_file($key)->openr );

    for my $x ([name => $key], [meta => encode_json($meta)], [etag => $md5->hexdigest]) {
        my $ofh = $od->file("${digest}." . $x->[0])->openw;
        print $ofh $x->[1];
        close $ofh;
    }
}

method get_key($key) {
    utf8::encode($key) if utf8::is_utf8($key);

    my $ret = decode_json( $self->meta_file($key)->slurp );

    my $x;
    if ( -f ($x = $self->etag_file($key))->stringify ) {
        $ret->{etag} = $x->slurp;
    }

    if ( -f ($x = $self->body_file($key))->stringify ) {
        $ret->{value} = $x->slurp;
    }

    return $ret;
}

method list_all_keys {
    my $object_dir = $->root->subdir("objects");
    my $dh = $object_dir->open;

    my @names;
    while (my $fn = $dh->read) {
        next unless $fn =~ /\.name$/;
        my $k = $object_dir->file($fn)->slurp;
        push @names, $k;
    }
    return @names;
}

method object_file($key, $name) {
    my $k2 = 
    my $digest = sha1_hex($key);
    return $self->root->subdir("objects")->file("${digest}.${name}");
}

method meta_file($key) {
    $->object_file($key, "meta")
}

method body_file($key) {
    $->object_file($key, "body")
}

method etag_file($key) {
    $->object_file($key, "etag")
}

1;

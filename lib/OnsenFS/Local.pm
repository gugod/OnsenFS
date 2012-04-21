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
use Path::Class;
use File::Path::Tiny;
use Digest::SHA1 qw(sha1_hex);
use Digest::MD5 qw(md5_hex);
use JSON;

has root => (
    is => "ro",
    isa => "Path::Class::Dir",
    required => 1
);

sub BUILD {
    my ($self) = @_;

    my $odir = $self->root->subdir("objects");

    unless (-d $odir) {
        File::Path::Tiny::mk($odir);
    }
}

sub add_key {
    my ($self, $key, $value, $meta) = @_;
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

use File::Copy;
sub link_or_copy {
    my ($oldfile, $newfile) = @_;
    return 1 if link($oldfile, $newfile);
    return 1 if copy($oldfile, $newfile);
    return 0;
}

sub add_key_filename {
    my ($self, $key, $filename, $meta) = @_;
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

sub get_key {
    my ($self, $key) = @_;

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

sub object_file {
    my ($self, $key, $name) = @_;
    my $digest = sha1_hex($key);
    return $self->root->subdir("objects")->file("${digest}.${name}");
}

sub meta_file {
    $_[0]->object_file($_[1], "meta")
}

sub body_file {
    $_[0]->object_file($_[1], "body")
}

sub etag_file {
    $_[0]->object_file($_[1], "etag")
}

1;

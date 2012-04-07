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

    my $digest = sha1_hex($key);

    unless (defined($meta)) {
        $meta = {};
    }

    my $od = $self->root->subdir("objects");

    for my $x ([body => $value], [name => $key], [meta => encode_json($meta)], [etag => md5_hex($value)]) {
        my $ofh = $od->file("${digest}." . $x->[0])->openw;
        print $ofh $x->[1];
        close $ofh;

    }
}

sub get_key {
    my ($self, $key) = @_;
    my $digest = sha1_hex($key);
    my $od = $self->root->subdir("objects");

    my $value = $od->file("${digest}.body")->slurp;
    my $meta = decode_json($od->file("${digest}.meta")->slurp);
    my $etag = $od->file("${digest}.etag")->slurp;

    return {
        %$meta,
        etag  => $etag,
        value => $value
    }
}

1;
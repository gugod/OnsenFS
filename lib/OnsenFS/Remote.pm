package OnsenFS::Remote;
use Moose;
use Net::Amazon::S3;

has access_key => (
    is => "rw",
    isa => "Str",
    required => 1
);

has secret_key => (
    is => "rw",
    isa => "Str",
    required => 1
);

has bucket_name => (
    is => "rw",
    isa => "Str",
    required => 1
);

has bucket => (
    is => "ro",
    isa => "Net::Amazon::S3::Bucket",
    required => 1,
    lazy => 1,
    builder => "_build_bucket",
    handles => ["get_key", "set_key", "head_key", "delete_key", "list", "list_all"]
);

sub _build_bucket {
    my ($self) = @_;
    my $s3 = Net::Amazon::S3->new(
        aws_access_key_id => $self->access_key,
        aws_secret_access_key => $self->secret_key,
        retry => 1
    );

    return $s3->bucket($self->bucket_name);
}

1;

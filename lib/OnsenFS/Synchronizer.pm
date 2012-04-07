use v5.14;
package OnsenFS::Synchronizer;
use Moose;
use Data::Recursive::Encode;
use Encode;

has local => (
    is => "ro",
    isa => "OnsenFS::Local",
    required => 1
);

has remote => (
    is => "ro",
    isa => "OnsenFS::Remote",
    required => 1
);

sub pull_indexes {
    my ($self) = @_;

    my $result;
    $result = $self->remote->list();

    while(1) {
        for my $o (map { Data::Recursive::Encode->encode(utf8 => $_) } @{ $result->{keys} }) {
            $self->local->add_key($o->{key}, undef, $o);
            say "# list => $o->{key}";
        }

        last unless $result->{is_truncated};

        my $x = $result->{next_marker} || $result->{keys}->[-1]->{key};
        $result = $self->remote->list({ marker => $x });
    }
}

sub pull_content {
    my ($self, $key) = @_;
    
}

sub run {
    my ($self) = @_;
    $self->pull_indexes;
}

1;

use v5.14;

package OnsenFS::LocalVFS::File {
    use Moose;
    use methods-invoker;

    has name   => (is => "ro", isa => "Str", required => 1);
    has mtime  => (is => "rw", isa => "Int", required => 0);
    has size   => (is => "rw", isa => "Int", required => 0);
    has parent => (is => "ro", isa => "Str", required => 1);

    has refresh_at => (
        is => "rw", isa => "Int", required => 1,
        default => sub { time }
    );

    use constant is_file => 1;
    use constant is_dir => 0;

    method path () {
        return $->parent . "/" . $->name;
    }
    method s3_key_name () {
        return $->path =~ s{^/}{}r;
    }
};

package OnsenFS::LocalVFS::Dir {
    use Moose;
    extends 'OnsenFS::LocalVFS::File';
    has '+refresh_at' => ( default => sub { 0 } );
    use constant is_file => 0;
    use constant is_dir => 1;

    has children => (
        is => "ro",
        isa => "ArrayRef",
        required => 1,
        default => sub { [ ] }
    );
};

package OnsenFS::LocalVFS;
use Moose;
use methods-invoker;

use Fcntl qw(:DEFAULT :mode :seek); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.
use Errno;
use Scalar::Util qw(refaddr);

use OnsenFS::Local;
use Path::Class ();
use DateTime::Format::ISO8601;

has root => (
    is => "ro",
    isa => "Str",
    required => 1
);

has onsen_local => (
    is => "rw",
    isa => "OnsenFS::Local",
    lazy => 1,
    builder => "_build_onsen_local"
);

has fs => (
    is => "rw",
    isa => "HashRef",
    lazy => 1,
    builder => '_build_fs'
);

method _build_onsen_local {
    OnsenFS::Local->new(root => Path::Class::dir($->root))
}

method _build_fs {
    my $fs = {};

    my @keys = $->onsen_local->list_all_keys;
    for my $k (@keys) {
        # say "# <= $k";
        my $f = Path::Class::file($k);
        my $p = $f->parent;
        my $v = $->onsen_local->get_key($k);

        $fs->{"$k"} = OnsenFS::LocalVFS::File->new(
            name   => $f->basename,
            parent => $f->parent->stringify,
            mtime  => DateTime::Format::ISO8601->parse_datetime($v->{last_modified})->epoch,
            size   => $v->{size}
        );

        $fs->{"$p"} ||= OnsenFS::LocalVFS::Dir->new(
            name   => $p->basename,
            parent => $p->parent->stringify,
            mtime  => time - 1,
            size   => 0
        );

        push @{ $fs->{"$p"}->children }, $fs->{"$k"};
        $f = $p;
        $p = $f->parent;

        while ($p ne "..") {
            unless ("$f" =~ m{/$}) {
                $fs->{"$p"} ||= OnsenFS::LocalVFS::Dir->new(
                    name   => $p->basename,
                    parent => $p->parent->stringify,
                    mtime  => time - 1,
                    size   => 0
                );

                push(@{ $fs->{"$p"}->children }, $fs->{"$f"}) unless grep { refaddr($_) eq refaddr($fs->{"$f"}) } @{ $fs->{"$p"}->children };
            }

            $f = $p;
            $p = $f->parent;
        }
    }

    $fs->{""} = delete $fs->{"."};

    return $fs;
}

method getdir($path) {
    utf8::decode($path) unless utf8::is_utf8($path);
    $path =~ s{^/}{};

    say "GETDIR($path)";

    my $x = $->fs->{$path};

    my @names;
    for (@{ $x->children }) {
        push @names, $_->name
    }

    return (@names, 0);
}

method getattr($path) {
    utf8::decode($path) unless utf8::is_utf8($path);
    $path =~ s{^/}{};

    say "GETATTR($path)";

    my ($inode, $mode, $size, $mtime) = (0, 0755, 0, time-1);

    my $f = $->fs->{$path} or return -Errno::ENOENT();

    if ($f->is_dir) {
        $mode |= S_IFDIR;
    }
    else {
        $mode |= S_IFREG;
    }

    $size  = $f->size;
    $inode = refaddr($f);
    $mtime = $f->mtime;

    return (
        0,                      # device number (?)
        $inode,                 # inode
        $mode,                  # mode
        1,                      # nlink
        $>,                     # uid
        $)+0,                   # gid
        0,                      # rdev
        $size,                  # size
        0,                      # atime
        $mtime,                 # mtime
        0,                      # ctime
        4096,                   # blocksize
        1+int($size/4096)       # blocks
    );
}

method open {
}

method read {
}

method release {
}

method statfs {
    my $s = 1024**3;
    return (90, $s, $s, $s, $s, 4096);
}

method unlink {
    0
}

method write {
    0
}

method create {
}

method mkdir {
}

method chmod {
    0
}

method chown {
    0
}

method flush {
    0
}

method fsync {
    0
}

method fsyncdir {
    0
}

method utime {
}

method setxattr {
    0
}

method getxattr {
    0
}

method listxattr {
    0
}

method removexattr {
    0
}

1;

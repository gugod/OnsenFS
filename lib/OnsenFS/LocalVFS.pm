use v5.14;
package OnsenFS::LocalVFS;
use Moose;
use methods-invoker;

use Fcntl qw(:DEFAULT :mode :seek); # S_IFREG S_IFDIR, O_SYNC O_LARGEFILE etc.
use Errno;
use Scalar::Util qw(refaddr);

use OnsenFS::Local;
use Path::Class ();

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

method _build_onsen_local {
    OnsenFS::Local->new(root => Path::Class::dir($->root))
}

method getdir($path) {
    utf8::decode($path) unless utf8::is_utf8($path);
    $path =~ s{^/}{};

    say "GETDIR $path";

    my @names;
    for my $k ($->onsen_local->list_all_keys) {
        if ($path) {
            next unless index($k, $path) == 0;
            $k =~ s{^$path}{};
        }

        my $x = [split("/", $k =~ s{^path}{}r)]->[0];
        push(@names, $x) unless !$x || grep { $_ eq $x } @names;
    }

    return (@names, 0);
}

method getattr($path) {
    utf8::decode($path) unless utf8::is_utf8($path);

    say "GETATTR $path";

    my ($inode, $mode, $size, $mtime) = (0, 0755, 0, time-1);

    $mode |= S_IFDIR;
    # $mode |= S_IFREG; # if $f->is_file;

    $size  = 0;
    $inode = 42;
    $mtime = time - 2;

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

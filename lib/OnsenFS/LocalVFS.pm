package OnsenFS::LocalVFS;
use Moose;
use methods-invoker;

use OnsenFS::Local;

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
    Onsen::Local->new(root => $->root)
}

method getdir {
}

method getattr {
}

method open {
}

method read {
}

method release {
}

method statfs {
}

method unlink {
}

method write {
}

method create {
}

method mkdir {
}

method chmod {
}

method chown {
}

method flush {
}

method fsync {
}

method fsyncdir {
}

method utime {
}

method setxattr {
}

method getxattr {
}

method listxattr {
}

method removexattr {
}

1;

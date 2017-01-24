#
# tests for fetch-build script
#
use v5.6.0;
use strict;
use warnings;

use Test::More;
use Test::Differences;

use Cwd                         qw(abs_path);
use File::Temp                  qw(tempdir);
use File::Copy                  qw(copy);
use File::Basename              qw(dirname basename);
use File::Path                  qw(mkpath);
use File::Spec;
use FindBin;

use RPM::Grill;

BEGIN {
    require_ok( "$FindBin::Bin/../bin/rpmgrill" );
}

sub prepare_testdata {
    my $test = shift;  # directory name from which to copy rpms from

    my $tempdir = tempdir("t-RPMGrill.XXXXXX", CLEANUP => !$ENV{DEBUG});
    my @rpms = glob(File::Spec->catfile(dirname(__FILE__), 'data', $test, '*.rpm'));

    foreach my $rpm (@rpms) {
        copy( $rpm, File::Spec->catfile($tempdir, basename($rpm)) );
    }

    my @unpack_cmd = ( "$FindBin::Bin/../bin/rpmgrill-unpack-rpms", $tempdir );
    system(@unpack_cmd) == 0
        or die "unpacking RPMs failed: $?";
    return $tempdir;
};

subtest 'RPMGrill exits with pass' => sub {
    my $tempdir = prepare_testdata('noerror');

    my @rpmgrill_cmd = ( "$FindBin::Bin/../bin/rpmgrill", File::Spec->catfile($tempdir, "unpacked") );
    my $exitcode = system(@rpmgrill_cmd);

    eq_or_diff($exitcode >> 8, 0, 'exits with a PASS');
};

subtest 'RPMGrill exits with test failure' => sub {
    my $tempdir = prepare_testdata('virus');

    my @rpmgrill_cmd = ( "$FindBin::Bin/../bin/rpmgrill", File::Spec->catfile($tempdir, "unpacked") );
    my $exitcode = system(@rpmgrill_cmd);

    # http://www.perlmonks.org/?node_id=81640
    eq_or_diff($exitcode >> 8, 1, 'exits with a failure');
};

done_testing();

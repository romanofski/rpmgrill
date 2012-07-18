# -*- perl -*-
#
# RPM::Grill::Plugin::ManPages - test for missing or bad man pages
#
# $Id$
#
# Real-world packages that trigger errors in this module:
# See t/RPM::Grill/Plugin/90real-world.t
#
package RPM::Grill::Plugin::ManPages;

use base qw(RPM::Grill);

use strict;
use warnings;
our $VERSION = '0.01';

use Carp;
use CGI                         qw(escapeHTML);
use IPC::Run                    qw(run timeout);

###############################################################################
# BEGIN user-configurable section

# Order in which this plugin runs.  Set to a unique number [0 .. 99]
sub order { 45 }

# One-line description of this plugin
sub blurb { return "checks for missing or badly-formatted man pages" }

# FIXME
sub doc {
    return <<"END_DOC" }
FIXME FIXME FIXME
END_DOC

# List of "important" directories. Used in _check_manpage_presence() to
# determine whether an executable needs a man page or not.
# FIXME: should this list be RHEL-dependent?
# FIXME: what about new RHEL7 init-script style?
our @Important_Bin_Directories = qw(/bin /sbin /usr/sbin /etc/init.d);
our $Important_Bin_Directories = join('|', @Important_Bin_Directories);

# END   user-configurable section
###############################################################################

# Program name of our caller
( our $ME = $0 ) =~ s|.*/||;

#
# input: a RPM::Grill object, blessed into this package.
# return value: not checked.
#
# Calls $self->gripe() with problems.  Return value is meaningless,
# but code can die/croak if necessary -- it will be trapped in an eval.
#
sub analyze {
    my $self = shift;

    # Step 1: go through all RPMs, collect manpages into an array
    $self->_gather_manpages();

    # Step 2: check each of those for correctness
    for my $manpage (@{ $self->{_manpages} }) {
        $self->_check_manpage_correctness($manpage);
    }

    # Step 3: warn about binaries without man pages
    for my $rpm ($self->rpms) {
        for my $f ($rpm->files) {
            $self->_check_manpage_presence($f);
        }
    }
}

######################
#  _gather_manpages  #  Initializes array of files that are (probably) man pages
######################
sub _gather_manpages {
    my $self = shift;                           # in: grill obj

    $self->{_manpages} = [];

    for my $rpm (grep { $_->arch ne 'src' } $self->rpms) {
        for my $f ($rpm->files) {
            if ($f->is_reg && $f->path =~ m|^/usr/share/man/|) {
                push @{ $self->{_manpages} }, $f;
            }
        }
    }
}

################################
#  _check_manpage_correctness  #  Look for man pages; run some checks on them
################################
sub _check_manpage_correctness {
    my $self    = shift;                        # in: grill obj
    my $manpage = shift;                        # in: Files obj

    # FIXME: can we assume that all manpages will be .gz ?
    $manpage->path =~ /\.[0-9n]\w*(\.gz)?$/ or do {
        $manpage->gripe({
            code => 'ManPageUnknownExtension',
            diag => "Man pages are expected to end in .[0-9n][a-z]*\.gz",
        });
        return;
    };

    my $content;

    if ($manpage->path =~ /\.gz$/) {
        my @cmd = ('gzip', '-dc', $manpage->extracted_path);
        my $stderr;
        run \@cmd, \undef, \$content, \$stderr, timeout(600);    # 10 min.
        my $exit_status = $?;

        if ($exit_status) {
            if ($stderr) {
                # gzip may include the file path in its error message.
                # Normalize it, so end users don't see /arch/payload/etc
                my $path_extracted = $manpage->extracted_path;
                my $path_plain     = $manpage->path;
                $stderr =~ s|\b$path_extracted\b|$path_plain|gs;

                # If the error is 'not in gzip format', invoke file(1)
                # and report what the file looks like
                if ($stderr =~ / not in gzip format\b/) {
                    $stderr .= " ('file' classifies this file as: " .
                        $manpage->file_type . ")";
                }

                $manpage->gripe({
                    code => 'ManPageBadGzip',
                    diag => "gunzip failed: " . escapeHTML($stderr),
                });
            }
            else {
                $manpage->gripe({
                    code => 'ManPageBadGzip',
                    diag => "Unknown error trying to gunzip file",
                });
            }
            return;
        }
        # No exit status.
    }
    else {
        # Not .gz; read directly. FIXME: can this happen?
        open my $fh, '<', $manpage->extracted_path or do {
            $manpage->gripe({
                code => 'ManPageReadError',
                diag => "Could not read file contents: $!",
            });
            return;
        };

        $content = do { local $/; <$fh>; };
        close $fh;
    }

    $content =~ /^\.(SH|Dd|so)/ms or do {
        $manpage->gripe({
            code => 'ManPageEmpty',
            diag => "No .SH, .Dd, or .so macros found; is this really a man page?",
        });
    };
}


#############################
#  _check_manpage_presence  #  "Important" executables must have a man page
#############################
sub _check_manpage_presence {
    my $self = shift;                           # in: Grill obj
    my $bin  = shift;                           # in: RPM::Grill::RPM::Files obj

    # We get invoked for all files, but we're only interested in:
    #   * regular files (i.e. not symlinks or directories) that are
    #   * ...executable and
    #   * ...in an important directory
    return unless $bin->is_reg;
    return unless $bin->numeric_mode & 0x100;
    return unless $bin->path =~ m{^($Important_Bin_Directories)/};

    # Got here. File is an executable in an important directory. Let's
    # make sure it has a corresponding man page.
    my $basename = $bin->basename;
    for my $manpage (@{ $self->{_manpages} }) {
        if ($manpage->path =~ m{/$basename\.[^/]+$}) {
            return if $manpage->rpm->arch eq $bin->arch
                   || $manpage->rpm->arch eq 'noarch';
        }
    }

    # No man page anywhere.
    $bin->gripe({
        code       => 'ManPageMissing',
        diag       => "No man page for " . $bin->path,
    });

    return;
}

1;

###############################################################################
#
# Documentation
#

=head1	NAME

FIXME - FIXME

=head1	SYNOPSIS

    use Fixme::FIXME;

    ....

=head1	DESCRIPTION

FIXME fixme fixme fixme

=head1	CONSTRUCTOR

FIXME-only if OO

=over 4

=item B<new>( FIXME-args )

FIXME FIXME describe constructor

=back

=head1	METHODS

FIXME document methods

=over 4

=item	B<method1>

...

=item	B<method2>

...

=back


=head1	EXPORTED FUNCTIONS

=head1	EXPORTED CONSTANTS

=head1	EXPORTABLE FUNCTIONS

=head1	FILES

=head1	SEE ALSO

L<>

=head1	AUTHOR

Ed Santiago <santiago@redhat.com>

=cut

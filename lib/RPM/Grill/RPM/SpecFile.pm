# -*- perl -*-
#
# RPM::Grill::RPM::SpecFile - RPM spec file-related stuff
#
# $Id$
#
package RPM::Grill::RPM::SpecFile;

use strict;
use warnings;
our $VERSION = '0.01';

use Carp;
use File::Basename      qw(basename);

###############################################################################
# BEGIN user-configurable section

# RPM sections. Generated from rpm sources via:
#
# perl -ne 'print $1,"\n" if /\{\s+PART_.*LEN_AND_STR\("%(\S+)"\)\}/' <build/parseSpec.c|column
our @RPM_Sections = split( /[\s\n]+/, <<'END_RPM_SECTIONS');
package         clean           pre             triggerpostun  verifyscript
prep            preun           post            triggerprein
build           postun          files           triggerun
install         pretrans        changelog       triggerin
check           posttrans       description     trigger
END_RPM_SECTIONS

our $RPM_Sections = join( '|', @RPM_Sections );

# END   user-configurable section
###############################################################################

# Program name of our caller
( our $ME = $0 ) =~ s|.*/||;

# In case someone wants our RPM_Sections list
our @ISA         = qw(Exporter);
our @EXPORT      = qw();
our @EXPORT_OK   = qw(@RPM_Sections);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

#########
#  new  #  Constructor.
#########
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $path  = shift                    # in: path to spec file
        or croak "Usage: " . __PACKAGE__ . "->new( ARG )";

    my $self = {
        path     => $path,
        lines    => [],
        sections => ['%preamble'],
    };

    my $fh;
    if ( $path =~ /\n/ ) {
        $self->{path} = '<string>';
        open $fh, '<', \$path
            or croak "$ME: Could not read from string filehandle: $!";
    }
    else {

        # Regular file
        open $fh, '<', $path
            or croak "$ME: " . __PACKAGE__ . ": Cannot read $path: $!";
    }

    my $section = $self->{sections}->[-1];

    while ( my $line = <$fh> ) {
        chomp $line;

        # FIXME: check section
        # FIXME: this can be complicated, eg:
        #    %files -n %{pkg_name}-server  [qpid-cpp-mrg-0.10-7.el5]
        if ( $line =~ m{^%($RPM_Sections)(\s+(.*))?\s*$}i ) {
            $section = '%' . lc($1);
            if ($3) {
                $section .= " " . $3;
            }

            push @{ $self->{sections} }, $section;
        }

        # FIXME: keep a list {content => [ { section => '', lines => [] } ]
        push @{ $self->{lines} },
            bless {
            lineno  => $.,
            section => $section,
            content => $line,
            },
            __PACKAGE__ . "::Line";

        # FIXME: invoke custom parser for this section?
    }
    close $fh;

    return bless $self, $class;
}

sub DESTROY { }

sub path {
    my $self = shift;

    return $self->{path};
}

sub sections {
    my $self = shift;

    return @{ $self->{sections} };
}

sub lines {
    my $self = shift;

    if (@_) {
        my $filter = shift;

        # We expect a section like '%prep', but allow our caller to say 'prep'
        $filter = '%' . $filter         unless $filter =~ /^%/;

        # FIXME: what if it's not a valid/known section?
        # FIXME: what if it's valid section, plus subpkg (%description foo) ?

        if (@_) {
            croak "$ME: " . __PACKAGE__ . "->lines(): Too many arguments";
        }

        return grep { $_->{section} eq $filter } @{ $self->{lines} };
    }

    # No filter: return all lines
    return @{ $self->{lines} };
}


###########
#  epoch  #  Value of 'Epoch: NN', or undef
###########
sub epoch {
    my $self = shift;

    my @match;
    for my $line ( $self->lines('%preamble') ) {
        if ($line->content =~ /^Epoch:\s*(\d+)$/) {
            push @match, $1;
        }
    }

    warn "$ME: WARNING: Specfile has multiple Epoch lines\n" if @match > 1;

    return $match[0];
}

###############################################################################
# BEGIN gripe and context

sub grill { return $_[0]->{grill} };

###########
#  gripe  #
###########
sub gripe {
    my $self  = shift;                  # in: RPM::Grill::RPM::SpecFile obj
    my $gripe = shift;                  # in: hashref with gripe info

    croak "$ME: ->gripe() called without args"        if ! $gripe;
    croak "$ME: ->gripe() called with too many args"  if @_;
    croak "$ME: ->gripe() called with a non-hashref"  if ref($gripe) ne 'HASH';

    my %gripe = (
        arch       => 'src',
        context    => $self->context,

        %$gripe,
    );

    $self->grill->gripe( \%gripe );
}

#############
#  context  #  helper for gripe
#############
sub context {
    my $self = shift;

    if (@_) {
        return $self->{gripe_context} = shift;
    }
    else {
        my %context;

        if (my $context = $self->{gripe_context}) {
            %context = %$context;
        }
        $context{path} = basename($self->path);

        return \%context;
    }
}

# END   gripe and context
###############################################################################
# BEGIN submodule

package RPM::Grill::RPM::SpecFile::Line;

use Carp;

sub AUTOLOAD {
    my $self = shift;

    our $AUTOLOAD;
    ( my $field = lc($AUTOLOAD) ) =~ s/^.*:://;

    if ( defined $self->{$field} ) {
        my $val = $self->{$field};
        if ( ref($val) ) {
            if ( ref($val) eq 'ARRAY' ) {
                return @$val;
            }
        }

        return $val;
    }

    croak "$ME: Unknown field " . __PACKAGE__ . "->$field()";
}

sub DESTROY { }

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

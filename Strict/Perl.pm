package Strict::Perl;
######################################################################
#
# Strict::Perl - Perl module to restrict old/unsafe constructs
#
# http://search.cpan.org/dist/Strict-Perl/
#
# Copyright (c) 2014 INABA Hitoshi <ina@cpan.org>
######################################################################

$Strict::Perl::VERSION = 2014.01;

use 5.00503;
use strict;
$^W = 1;

# verify that we're called correctly so that strictures will work.
if (__FILE__ !~ m{ \b Strict[/\\]Perl\.pm \z}x) {
    my($package,$filename,$line) = caller;
    die "Incorrect use of module '${\__PACKAGE__}' at $filename line $line.\n";
}

use vars qw($VERSION_called);
sub VERSION {
    my($self,$version) = @_;
    if ($version != $Strict::Perl::VERSION) {
        my($package,$filename,$line) = caller;
        die "$self $version required--this is version $Strict::Perl::VERSION, stopped at $filename line $line.\n";
    }
    $VERSION_called = 1;
}

sub import {
    my($self) = @_;

    # must VARSION require
    unless ($VERSION_called) {
        my($package,$filename,$line) = caller;
        die "$self $Strict::Perl::VERSION version required like 'use $self $Strict::Perl::VERSION;', stopped at $filename line $line.\n";
    }

    my @mustword = qw(VERSION);
    my %used = ();

    # disable considered statements and variables
    if (open(SCRIPT,$0)) {
        local $.;
        while (<SCRIPT>) {
            if (/ \b (
                goto   | redo   | until    | foreach |
                format | write  | formline |
                msgctl | msgget | msgrcv   | msgsnd  |
                semctl | semget | semop    |
                shmctl | shmget | shmread  | shmwrite

            ) \b /x) { # Oops! I did little overkill.
                die "Use of '$1' statement deprecated in line $.\n";
            }
            elsif (/ (
                \$ARRAY_BASE \b                            | \$\[     |
                                               \$OFMT \b   | \$\#     |
                                                             \@F \b   |
                                                             \$\^H \b |

                \$OUTPUT_FIELD_SEPARATOR \b  | \$OFS \b    | \$\,     |
                \$OUTPUT_RECORD_SEPARATOR \b | \$ORS \b    | \$\\     |
                \$LIST_SEPARATOR \b                        | \$\"     |
                \$SUBSCRIPT_SEPARATOR \b     | \$SUBSEP \b | \$\;     |

                \$MULTILINE_MATCHING \b                    | \$\*     |
                \$PREMATCH \b                              | \$\`     |
                \$MATCH \b                                 | \$\&     |
                \$POSTMATCH \b                             | \$\'     |

                \$FORMAT_PAGE_NUMBER \b                    | \$\%     |
                \$FORMAT_LINES_PER_PAGE \b                 | \$\=     |
                \$FORMAT_LINES_LEFT \b                     | \$\-     |
                \$FORMAT_NAME \b                           | \$\~     |
                \$FORMAT_TOP_NAME \b                       | \$\^     |
                \$FORMAT_LINE_BREAK_CHARACTERS \b          | \$\:     |
                \$FORMAT_FORMFEED \b                       | \$\^L \b |
                \$ACCUMULATOR \b                           | \$\^A \b

            ) /x) {
                die "Use of special variable '$1' deprecated in line $.\n";
            }
            elsif (/ ( ~~ ) /x) {
                die "Use of operator '$1' deprecated in line $.\n";
            }
            for my $mustword (@mustword) {
                if (/ \b $mustword \b /x) {
                    $used{$mustword} = 1;
                }
            }
        }
        close(SCRIPT);
    }

    for my $mustword (@mustword) {
        if (not $used{$mustword}) {
            die "'$mustword' not found in $0.\n";
        }
    }

    # use warnings qw(FATAL all);
    $SIG{__WARN__} =

    # HACK #55 Show Source Code on Errors in Chapter 6: Debugging of PERL HACKS
    $SIG{__DIE__}  = sub {
        print STDERR __PACKAGE__, ': ';
        print STDERR "$^E\n" if defined($^E);
        print STDERR "$_[0]\n";

        my $i = 0;
        my @confess = ();
        while (my($package,$filename,$line,$subroutine) = caller($i)) {
            push @confess, [$i,$package,$filename,$line,$subroutine];
            $i++;
        }
        for my $confess (reverse @confess) {
            my($i,$package,$filename,$line,$subroutine) = @{$confess};
            next if $package eq __PACKAGE__;
            next if $package eq 'Carp';

            print STDERR "[$i] $subroutine in $filename\n";
            if (open(SCRIPT,$filename)) {
                my @script = (undef,<SCRIPT>);
                close(SCRIPT);
                printf STDERR "%04d: $script[$line-2]", $line-2 if (($line-2) >= 1);
                printf STDERR "%04d: $script[$line-1]", $line-1 if (($line-1) >= 1);
                printf STDERR "%04d* $script[$line+0]", $line+0 if defined($script[$line+0]);
                printf STDERR "%04d: $script[$line+1]", $line+1 if defined($script[$line+1]);
                printf STDERR "%04d: $script[$line+2]", $line+2 if defined($script[$line+2]);
                printf STDERR "\n";
            }
        }
        exit(1);
    };

    # use autodie;
    if ($] > 5.012) {
        require autodie;
        package main;
        autodie::->import;
    }

    # use Fatal qw(...);
    else {
        require Fatal;
        package main;
        Fatal::->import(
            qw(seek sysseek),                                                                   # :io (excluded: read sysread syswrite)
            qw(dbmclose dbmopen),                                                               # :dbm
            qw(binmode close chmod chown fcntl flock ioctl open sysopen truncate),              # :file (excluded: fileno)
            qw(chdir closedir opendir link mkdir readlink rename rmdir symlink),                # :filesys (excluded: unlink)
            qw(pipe),                                                                           # :ipc
            qw(msgctl msgget msgrcv msgsnd),                                                    # :msg
            qw(semctl semget semop),                                                            # :semaphore
            qw(shmctl shmget shmread),                                                          # :shm
            qw(accept bind connect getsockopt listen recv send setsockopt shutdown socketpair), # :socket
            qw(fork),                                                                           # :threads
        );
    }

    # use strict;
    require strict;
    strict::->import;

    # use warnings;
    if ($] > 5.006) {
        require warnings;
        warnings::->import;
    }

    # use English; $WARNING = 1;
    else {
        $^W = 1;

#       # read only $^W
#       tie $^W, __PACKAGE__;
    }
}

# make read-only scalar variable
sub TIESCALAR { bless \my $scalar, $_[0] }
sub FETCH     { $$_[0] }
sub STORE     { require Carp; Carp::croak("Can't modify read-only variable"); }

1;

__END__

=pod

=head1 NAME

  Strict::Perl - Perl module to restrict old/unsafe constructs

=head1 SYNOPSIS

  use Strict::Perl 2014.01; # must version, must match

=head1 DESCRIPTION

Strict::Perl provides a restricted scripting environment excluding old/unsafe
constructs, on both modern Perl and traditional Perl.

Version specify is required when use Strict::Perl, like;

  use Strict::Perl 2014.01;

It's die if specified version doesn't match Strict::Perl's version.

On Perl 5.12 or later, Strict::Perl works as;

  use strict;
  use warnings qw(FATAL all);
  use autodie;

On Perl 5.6 or later,

  use strict;
  use warnings qw(FATAL all);
  use Fatal qw(
      seek sysseek
      dbmclose dbmopen
      binmode close chmod chown fcntl flock ioctl open sysopen truncate
      chdir closedir opendir link mkdir readlink rename rmdir symlink
      pipe
      msgctl msgget msgrcv msgsnd
      semctl semget semop
      shmctl shmget shmread
      accept bind connect getsockopt listen recv send setsockopt shutdown socketpair
      fork
  );

On Perl 5.00503 or later,

  use strict;
  $^W = 1;
  $SIG{__WARN__} = sub { die "$_[0]\n" };
  use Fatal qw(
      seek sysseek
      dbmclose dbmopen
      binmode close chmod chown fcntl flock ioctl open sysopen truncate
      chdir closedir opendir link mkdir readlink rename rmdir symlink
      pipe
      msgctl msgget msgrcv msgsnd
      semctl semget semop
      shmctl shmget shmread
      accept bind connect getsockopt listen recv send setsockopt shutdown socketpair
      fork
  );

Prohibited Keywords in your script are;

  goto  redo  until  foreach  format  write  formline
  msgctl  msgget  msgrcv  msgsnd  semctl  semget  semop
  shmctl  shmget  shmread  shmwrite

Prohibited Special Variables are;

  $ARRAY_BASE                        $[
  $OFMT                              $#
                                     @F
                                     $^H
  $OUTPUT_FIELD_SEPARATOR   $OFS     $,
  $OUTPUT_RECORD_SEPARATOR  $ORS     $\
  $LIST_SEPARATOR                    $"
  $SUBSCRIPT_SEPARATOR      $SUBSEP  $;
  $MULTILINE_MATCHING                $*
  $PREMATCH                          $`
  $MATCH                             $&
  $POSTMATCH                         $'
  $FORMAT_PAGE_NUMBER                $%
  $FORMAT_LINES_PER_PAGE             $=
  $FORMAT_LINES_LEFT                 $-
  $FORMAT_NAME                       $~
  $FORMAT_TOP_NAME                   $^
  $FORMAT_LINE_BREAK_CHARACTERS      $:
  $FORMAT_FORMFEED                   $^L
  $ACCUMULATOR                       $^A

Prohibited Operator is;

  ~~ (smartmatch)

Must Keyword in your script is;

  VERSION

Be useful software for you!

=head1 AUTHOR

INABA Hitoshi E<lt>ina@cpan.orgE<gt>

This project was originated by INABA Hitoshi.

=head1 LICENSE AND COPYRIGHT

This software is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=head1 SEE ALSO

=over 4

=item * L<ina|http://search.cpan.org/~ina/> - CPAN

=item * L<The BackPAN|http://backpan.perl.org/authors/id/I/IN/INA/> - A Complete History of CPAN

=back

=cut


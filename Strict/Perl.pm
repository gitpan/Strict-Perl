package Strict::Perl;
######################################################################
#
# Strict::Perl - Perl module to restrict old/unsafe constructs
#
# http://search.cpan.org/dist/Strict-Perl/
#
# Copyright (c) 2014 INABA Hitoshi <ina@cpan.org>
######################################################################

$Strict::Perl::VERSION = 2014.06;

use 5.00503;
use strict;
local $^W = 1;

# use strict;
sub _strict {
    require strict;
    if (($] < 5.006) and exists $INC{'Fake/Our.pm'}) {
        # no strict qw(vars); on Fake::Our used
    }
    else {
        strict::->import(qw(vars));
    }
    strict::->import(qw(refs subs));
}

# use warnings;
sub _warnings {
    require warnings;
    warnings::->import;
}

# install Fatal CORE::* functions
sub _Fatal {
    my $package = (caller(1))[0];
    for my $function (
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
    ) {
        _install_fatal_function($function, $package);
    }
}

# make fatal invocation
sub _fatal_invocation {
    my($function, $proto) = @_;

    my $n = -1;
    local @_ = ();
    my @prototype = ();
    my $seen_semicolon = 0;

    $proto =~ s/^_;/;\$/;
    $proto =~ s/^_/;\$/;
    while ($proto =~ /\S/) {
        $n++;
        if ($seen_semicolon) {
            push @prototype, [$n, @_];
        }
        if ($proto =~ s/^\s*\\([\@%\$\&])//) {
            push @_, $1 . "{\$_[$n]}";
            next;
        }
        if ($proto =~ s/^\s*([*\$&])//) {
            push @_, "\$_[$n]";
            next;
        }
        if ($proto =~ s/^\s*(;\s*)?\@//) {
            push @_, "\@_[$n..\$#_]";
            last;
        }
        if ($proto =~ s/^\s*;//) {
            $seen_semicolon = 1;
            $n--;
            next;
        }
        die "Unknown prototype letters: \"$proto\"";
    }
    push @prototype, [$n+1, @_];

    if (@prototype == 1) {
        my @argv = @{$prototype[0]};
        shift @argv;
        local $" = ', ';
        return qq{\tCORE::$function(@argv) || croak "Can't $function(\@_): \$!";};
    }
    else {
        local @_ = <<END;
\tif (0) {
\t}
END
        while (@prototype) {
            my @argv = @{shift @prototype};
            my $n = shift @argv;
            local $" = ', ';
            push @_, <<END;
\telsif (\@_ == $n) {
\t\treturn CORE::$function(@argv) || croak "Can't $function(\@_): \$!";
\t}
END
        }
        push @_, qq{\tdie "$function(\@_): Do not expect to get ", scalar \@_, " arguments";};
        return join '', @_;
    }
}

# install Fatal function to package
sub _install_fatal_function {
    my($function, $package) = @_;

    my $proto = eval { prototype "CORE::$function" };
    if ($@) {
        die "$function is not a builtin";
    }
    if (not defined $proto) {
        die "Cannot install a fatal function since non-overridable builtin";
    }

    my $code = <<END;
sub ($proto) {
\tlocal \$" = ', ';
\tlocal \$! = 0;
@{[_fatal_invocation($function,$proto)]}
}

END
    {
        no strict 'refs';
        $code = eval "package $package; use Carp; $code";
        die if $@;
        local $^W = 0;
        *{"${package}::$function"} = $code;
    }
}

# use autodie qw(...);
sub _autodie {
    require autodie;
    package main;
    autodie::->import(
        qw(read sysread syswrite), # :io
        qw(fileno),                # :file
        # nothing                  # :filesys (excluded: unlink)
    );
}

# $SIG{__WARN__}, $SIG{__DIE__}
sub _SIG {

    # use warnings qw(FATAL all);
    $SIG{__WARN__} = sub {

        # avoid: Use of reserved word "our" is deprecated
        if (($_[0] =~ /^Use of reserved word "our" is deprecated at /) and exists $INC{'Fake/Our.pm'}) {
            # ignore message
        }

        # ignore wrong warning: Name "main::BAREWORD" used only once
        elsif ($_[0] =~ /Name "main::[A-Za-z_][A-Za-z_0-9]*" used only once:/) {
            if ($] < 5.012) {
                # ignore message
            }
            else {
                $SIG{__DIE__}->(@_);
            }
        }
        else {
            $SIG{__DIE__}->(@_);
        }
    };

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
}

# perl 5.000 or later
sub BEGIN {

    # $SIG{__WARN__}, $SIG{__DIE__}
    _SIG();
}

# perl 5.010 or later
sub UNITCHECK {
}

# perl 5.006 or later
sub CHECK {

    # use warnings;
    _warnings();
}

# perl 5.005 or later
sub INIT {

    # use English; $WARNING = 1;
    $^W = 1;
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

    # verify that we're called correctly so that strictures will work.
    if (__FILE__ !~ m{ \b Strict[/\\]Perl\.pm \z}x) {
        my($package,$filename,$line) = caller;
        die "Incorrect use of module '${\__PACKAGE__}' at $filename line $line.\n";
    }

    # must VARSION require
    unless ($VERSION_called) {
        my($package,$filename,$line) = caller;
        die "$self $Strict::Perl::VERSION version required like 'use $self $Strict::Perl::VERSION;', stopped at $filename line $line.\n";
    }

    # use strict;
    _strict();

    # use Fatal qw(...); --- compatible routine
    _Fatal();

    # use autodie qw(...);
    if ($] >= 5.010001) {
        _autodie();
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
                shmctl | shmget | shmread  | shmwrite |
                given  | when

            ) \b /x) { # Oops! I did little overkill.
                die "Use of '$1' statement deprecated in line $.\n";
            }
            elsif (/ (
                \$ARRAY_BASE \b                            | \$\[     |
                                               \$OFMT \b   | \$\# (?![A-Za-z_\{]) |
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
                \$FORMAT_TOP_NAME \b                       | \$\^ (?![A-Za-z_\{]) |
                \$FORMAT_LINE_BREAK_CHARACTERS \b          | \$\: (?![:])         |
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
}

1;

__END__

=pod

=head1 NAME

  Strict::Perl - Perl module to restrict old/unsafe constructs

=head1 SYNOPSIS

  use Strict::Perl 2014.06; # must version, must match

=head1 DESCRIPTION

Strict::Perl provides a restricted scripting environment excluding old/unsafe
constructs, on both modern Perl and traditional Perl.

Strict::Perl works in concert with Fake::Our if Fake::Our is used in your
script.

Version specify is required when use Strict::Perl, like;

  use Strict::Perl 2014.06;

It's die if specified version doesn't match Strict::Perl's version.

On Perl 5.010001 or later, Strict::Perl works as;

  use strict;
  use warnings qw(FATAL all);
  use Fatal qw( # by compatible routine in Strict::Perl
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
  use autodie qw(
      read sysread syswrite
      fileno
  );

On Perl 5.006 or later,

  use strict;
  use warnings qw(FATAL all);
  use Fatal qw( # by compatible routine in Strict::Perl
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
  use Fatal qw( # by compatible routine in Strict::Perl
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

  goto  redo  until  foreach
  format  write  formline
  msgctl  msgget  msgrcv  msgsnd
  semctl  semget  semop
  shmctl  shmget  shmread  shmwrite
  given  when

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

=item * L<A Complete History of CPAN|http://backpan.perl.org/authors/id/I/IN/INA/> - The BackPAN

=back

=cut


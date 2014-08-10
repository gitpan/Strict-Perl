use 5.00503;
use strict;

use vars qw(@test);

BEGIN {
    @test = (

    '001_exit.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
exit;
END

    '002_die.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
die;
END

    '003_must_moduleversion.pl' => [<<'END', 'die'],
use Strict::Perl;
use vars qw($VERSION);
$VERSION = 1;
exit;
END

    '004_must_moduleversion_match.pl' => [<<'END', 'die'],
use Strict::Perl 9999.99;
use vars qw($VERSION);
$VERSION = 1;
exit;
END

    '005_must_scriptversion.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
exit;
END

    '006_strict.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
$VERSION = 1;
$VAR = 1;
exit;
END

    '007_warnings.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
print "VERSION=$VERSION";
exit;
END

    '008_autodie.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
open(FILE,'not_exists.txt');
close(FILE);
exit;
END

    '009_badword_goto.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
goto LABEL;
print "LINE=", __LINE__, "\n";
LABEL:
print "LINE=", __LINE__, "\n";
exit;
END

    '010_badword_given.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
given ($_) {
    if ($_ =~ /Strict::Perl/) {
        print "Strict::Perl\n";
    }
}
exit;
END

    '011_badword_when.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
for ($_) {
    when ($_ =~ /Strict::Perl/) {
        print "Strict::Perl\n";
    }
}
exit;
END

    '012_badvariable.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
print "\$[=($[)\n";
exit;
END

    '013_goodvariable.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
print "\$^W=($^W)\n";
exit;
END

    '014_badoperator.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
if ('Strict' ~~ 'Perl') {
    print "Strict::Perl\n";
}
exit;
END

    '015_bareword.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
open(FILE,$0);
close(FILE);
exit;
END

    '016_fileno_0.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
print "fileno(STDIN)=(",fileno(STDIN),")\n";
exit;
END

    '017_fileno_undef.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
print "fileno(FILE)=(",fileno(FILE),")\n";
exit;
END

    '018_unlink.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
unlink('not_exists.txt');
exit;
END

    '019_use_Thread.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
use Thread;
exit;
END

    '020_use_threads.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
use threads;
exit;
END

    '021_use_encoding.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
use encoding;
exit;
END

    '022_use_Switch.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
use Switch;
exit;
END

    );

    use vars qw($tests);
    $tests = scalar(@test) / 2;

    $| = 1;
    eval {
        require Test::Simple;
        Test::Simple::->import('tests' => $tests);
    };
    if ($@) {
        print "1..$tests\n";
        eval q{
            use vars qw($tno $ok);
            $tno = 1;
            $ok = 0;
            sub ok {
                if ($_[0]) {
                    print "ok $tno - $_[1]\n";
                    $ok++;
                }
                else {
                    print "not ok $tno - $_[1]\n";
                }
                $tno++;
            }
            $SIG{__DIE__} = sub { exit(255) };
            sub END {
                exit((($tests-$ok)<=254) ? ($tests-$ok) : 254);
            }
        };
    }
}

# get $Strict::Perl::VERSION
BEGIN {
    require Strict::Perl;
}

while (@test > 0) {
    my $scriptname    = shift @test;
    my($script,$want) = @{shift @test};

    open(SCRIPT,"> $scriptname") || die "Can't open file: $scriptname\n";
    $script =~ s/<%MODULEVERSION%>/$Strict::Perl::VERSION/;
    print SCRIPT $script;
    close(SCRIPT);

    my $rc;
    if ($^O eq 'MSWin32') {
        $rc = system(qq{$^X $scriptname >NUL 2>NUL});
    }
    else {
        $rc = system(qq{$^X $scriptname >/dev/null 2>/dev/null});
    }
    unlink($scriptname);

    ok(((($want eq 'die') and ($rc != 0)) or (($want ne 'die') and ($rc == 0))), "perl/$] $scriptname $want");
}

__END__

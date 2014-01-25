use 5.00503;
use strict;

use vars qw(@test);

BEGIN {
    @test = (

    'exit.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
exit;
END

    'die.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
die;
END

    'must_moduleversion.pl' => [<<'END', 'die'],
use Strict::Perl;
use vars qw($VERSION);
$VERSION = 1;
exit;
END

    'must_moduleversion_match.pl' => [<<'END', 'die'],
use Strict::Perl 9999.99;
use vars qw($VERSION);
$VERSION = 1;
exit;
END

    'must_scriptversion.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
exit;
END

    'strict.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
$VERSION = 1;
$VAR = 1;
exit;
END

    'warnings.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
print "VERSION=$VERSION";
exit;
END

    'autodie.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
open(FILE,'not_exists.txt');
close(FILE);
exit;
END

    'badword.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
goto LABEL;
print "LINE=", __LINE__, "\n";
LABEL:
print "LINE=", __LINE__, "\n";
exit;
END

    'badvariable.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
print "\$[=($[)\n";
exit;
END

    'goodvariable.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
print "\$^W=($^W)\n";
exit;
END

    'badoperator.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
if ('Strict' ~~ 'Perl') {
    print "Strict::Perl\n";
}
exit;
END

    'bareword.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
open(FILE,$0);
close(FILE);
exit;
END

    'fileno_0.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
print "fileno(STDIN)=(",fileno(STDIN),")\n";
exit;
END

    'fileno_undef.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
print "fileno(FILE)=(",fileno(FILE),")\n";
exit;
END

    'unlink.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
unlink('not_exists.txt');
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

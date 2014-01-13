use strict;

$| = 1;
print "1..10\n";

my %test = (

'001_ok.pl' => [<<'END', 'notdie'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
END

'002_must_moduleversion.pl' => [<<'END', 'die'],
use Strict::Perl;
use vars qw($VERSION);
$VERSION = 1;
END

'003_must_moduleversion_match.pl' => [<<'END', 'die'],
use Strict::Perl 9999.99;
use vars qw($VERSION);
$VERSION = 1;
END

'004_strict.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
$VERSION = 1;
END

'005_warnings.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
print "VERSION=$VERSION";
END

'006_autodie.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
open(FILE,'not_exists.txt');
close(FILE);
END

'007_badword.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
goto LABEL;
print "LINE=", __LINE__, "\n";
LABEL:
print "LINE=", __LINE__, "\n";
END

'008_badvariable.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
print "\$[=$[\n";
END

'009_badoperator.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
use vars qw($VERSION);
$VERSION = 1;
if ('Strict' ~~ 'Perl') {
    print "Strict::Perl\n";
}
END

'010_must_scriptversion.pl' => [<<'END', 'die'],
use Strict::Perl <%MODULEVERSION%>;
END

);

require Strict::Perl; # get $Strict::Perl::VERSION

my $tno = 1;
for my $scriptname (sort keys %test) {
    my($script,$want) = @{$test{$scriptname}};

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

    if (($want eq 'die') and ($rc != 0)) {
        print "ok - $tno $^X $scriptname\n";
    }
    elsif (($want ne 'die') and ($rc == 0)) {
        print "ok - $tno $^X $scriptname\n";
    }
    else {
        print "not ok - $tno want=$want, rc=$rc $^X $scriptname\n";
    }

    unlink($scriptname);

    $tno++;
}

__END__

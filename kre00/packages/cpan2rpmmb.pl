#!/usr/bin/perl

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

eval 'exec /usr/bin/perl  -S $0 ${1+"$@"}'
    if 0; # not running under some shell

#
#   cpan2rpm - CPAN module RPM maker
#   Copyright (C) 2001-2003 Erick Calder
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

use vars qw($VERSION $VX);
$VERSION = "2.027";

# --- prologue ----------------------------------------------------------------

use strict;
use warnings;
use Getopt::Long;
use Sys::Hostname;
use Pod::Text;

my ($ME, $RPM, $TMPDIR, %RPMDIR, $CWD, %info, %meta, $ARGS);

my $tarRE = q/\.(tar\.(g?z|bz2)|tgz|zip)$/;
my $docRE = '(readme|changes|todo|license|install|\.txt|\.html)';
my $HTTPWARN = 0;   # so we don't repeat warnings
my $SPECCOL = 10;   # col width for generated spec files

*OLDOUT = *OLDERR = *OLDIN = "";

# --- main() ------------------------------------------------------------------

init();             # initialise stuff

for (@ARGV) {
    get_mod();      # retrieve a module to work with
    get_meta();     # get metadata from tarball
    mk_spec();      # create a custom spec file
    mk_rpm();       # build the RPM
    inst_rpm();     # install it if requested
    }

# --- support functionality ---------------------------------------------------

END {
    chdir $CWD;
    return print("$VERSION\n") if $VX;
    print "-- Done --\n";
    }

# Stub routine required to prevent destruction of fresh Makefile
sub MM::flush {}

sub init {
    $|++;    # good for system()
    ($ME = $0) =~ s|.*/||;

    $ENV{PATH} = "/bin:/usr/bin";       # makes suexec happy
    chomp($CWD = untaint(qx/pwd/));     # remember where we start

    $RPM = inpath("rpmbuild");
    $RPM = inpath("rpm") unless $RPM;
    die "Cannot find rpmbuild/rpm in PATH" unless $RPM;

    # package info defaults

    %info = (
        url               => "http://www.cpan.org",
        packager          => "Arix International <cpan2rpm\@arix.com>",
        group             => "Applications/CPAN",
        license           => "GPL",
        release           => 1,
        buildroot         => "%{_tmppath}/%{name}-%{version}-%(id -u -n)",
        defattr           => "-,root,root",
        description       => "None.",
        );

    my %desc = (
        # -- simple options
        "name=s"          => "RPM package name",
        "no-prfx"         => "suppresses package name prefix",
        "no-depchk"       => "suppresses dependency check",
        "summary=s"       => "package summary",
        "version=s"       => "override the CPAN version number",
        "release=s"       => "RPM release number",
        "epoch=i"         => "the package epoch",
        "author=s"        => "author information",
        "packager=s"      => "packager identification",
        "defattr=s"       => "ownership information for installed files",
        "distribution=s"  => "RPM distribution",
        "license=s"       => "licensing information",
        "group=s"         => "RPM group",
        "url=s"           => "home URL",
        "buildroot=s"     => "root directory to use for build",
        "buildarch=s"     => "package architecture",
        "description=s"   => "package description",
        # -- aggregate options
        "requires=s@"     => "packages required for installation",
        "provides=s@"     => "modules provided by the package",
        "buildrequires=s@" => "packages required for building",
        "no-requires=s@"  => "suppresses generation of a set of reqs",
        "source|s=s@"     => "specifies (multiple) sources to use",
        "patch|p=s@"      => "specifies (multiple) patches to apply",
        "doc=s"           => "adds to the spec's %doc section",
        "define=s@"       => "define macros",
        # -- section options
        "prologue=s@"     => "inserts text at beginning of section",
        "epilogue=s@"     => "inserts text at end of section",
        # -- build options
        "spec-only"       => "only generates spec file",
        "spec=s"          => "specifies the name of a spec file",
        "make-maker=s"    => "arguments for makefile creation",
        "make=s"          => "arguments passed to make",
        "make-no-test"    => "suppress running test suite",
        "make-install=s"  => "arguments for make install",
        "find-provides=s" => "instructs us to use a given filter",
        "find-requires=s" => "(see man page for further details)",
        "tempdir=s"       => "specify temporary working directory",
        "req-scan-all"    => "scan all files in a tarball for reqs",
        "no-clean"        => "suppress --clean",
        "shadow-pure"     => "override existing pure perl module",
        "no-sign"         => "prevents signing the package",
        "install|i"       => "install package when done",
        "force"           => "forces all operations",
        # -- miscellaneous options
        "fetch=s"         => "fetch method for modules",
        "modules|f=s"     => "file containing module list",
        "mk-rpm-dirs=s"   => "creates RPM dirs for non-root users",
        "sign-setup:s"    => "sets up RPM to support signatures",
        "upgrade"         => "upgrades cpan2rpm",
        "no-upgrade-chk|U" => "no version checks",
        "debug:i"         => "produce debugging output",
        "keep-pipes"      => "prevents pipe closing for web UIs",
        "help|h"          => "this help screen",
        "V"               => "cpan2rpm version",
        "D"               => "runs the perl debugger",
	"post=s"          => "post install commands", # Mediaburst Bit
        "pre=s"           => "pre install commands", # Mediaburst Bit
	"no-auto-prov"    => "suppress RPM provides auto generation", # Mediaburst Bit
        );

    # get user options from config file ~/.cpan2rpm

    my $cfg = "$ENV{HOME}/.$ME";
    if (-r $cfg) {
        eval "use Getopt::ArgvFile qw/argvFile/";
        if ($@) {
            print "\n-- cpan2rpm - Ver: $VERSION --\n";
            my $msg = "A configuration file [$cfg] is present\n";
            $msg .= "but the module [Getopt::ArgvFile] is not available.\n";
            $msg .= "Either install the module or remove the config file.\n";
            die $msg;
            }
        argvFile(home=> 1);
        }

    # get user options from command line

    my %opts = ();
    my @args = grep !/^-D$/, @ARGV;
    $ARGS = join " ", map {/\s/ ? qq/'$_'/ : $_} @args;
    my $ret = GetOptions(\%opts, keys %desc);

    exec("$^X -d $0 " . join(" ", @args)) if $opts{D};
    $VX++, exit if $opts{V};

    print "\n-- cpan2rpm - Ver: $VERSION --\n";
    syntax(\%desc) if defined $opts{help} || !$ret;

    # a clarification on the various keys used in %info:
    #   dist     =  user entry of the form <directory>, <tarball-path>,
    #               <url>, <module-name> - this value may undergo translation
    #               to eventually evaluate to a filesystem reference
    #   tarball  =  always located in SOURCES.  Proc-Daemon-1.0.tgz
    #   name     =  Proc-Daemon
    #   module   =  Proc::Daemon
    #   evaldir  =  directory where tarball is extracted
    #   tardir   =  the directory name inside the tarball

    %info = (%info, %opts);

    $info{debug} = 1 if defined $info{debug} && $info{debug} == 0;
    print "DEBUG=ON [$info{debug}]\n" if $info{debug};

    #   set up local account to build packages

    if ($info{"mk-rpm-dirs"}) {
        mk_rpm_dirs();
        exit;
        }

    if (defined $info{"sign-setup"}) {
        sign_setup();
        exit;
        }

    #   handle temporary files

    if ($TMPDIR = $info{tempdir}) {
        mkdir $TMPDIR, 0755 unless -d $TMPDIR;
        }
    else {
        my $msg = "Cannot run without File::Temp, please install ";
        $msg .= "or use the --tempdir option.\n";
        eval "use File::Temp qw/tempdir/";
        $msg = "$@\n$msg" if $info{debug};
        die $msg if $@;

        $info{dist} ||= "";
        $TMPDIR = tempdir(
            CLEANUP => $info{"no-clean"} || -d $info{dist} ? 0 : 1
            );
        };

    upgrade() if defined $info{upgrade};

    unless ($info{"no-sign"}) {
        my $sig = getrpm_macdef("_signature");
        $sig =~ s/none//i;
        $sig && ($info{sign} = "--sign") || print "Signatures not set up\n";
        }

    #   deal with newer versions
    chkupgrade();

    # check directory permissions

    $RPMDIR{BUILD} = getrpm_macdef("_builddir");
    $RPMDIR{SOURCES} = getrpm_macdef("_sourcedir");
    $RPMDIR{RPMS} = getrpm_macdef("_rpmdir");
    $RPMDIR{SRPMS} = getrpm_macdef("_srcrpmdir");
    $RPMDIR{SPECS} = getrpm_macdef("_specdir");
    $RPMDIR{ARCH} = getrpm_macdef("_arch");
    chkdirs();

    # sets empty string if not --buildarch and --spec-only
    $info{buildarch} ||= $info{"spec-only"} ? "" : $RPMDIR{ARCH};

    # set module download method

    my %cpan = (
        cpanplus => \&get_cpan_plus,
        cpan => \&get_cpan_old,
        web => \&get_cpan_web
        );

    if ($info{fetch}) {
        $info{fetch} = lc($info{fetch});
        die "Invalid fetch method specified.  See man page for --fetch\nStopped"
            unless $info{fetch} =~ /cpanplus|cpan|web/;
        }

    $@ = "";
    $info{fetch} ||= "web";  # default
    if ($info{fetch} eq "cpanplus" && (eval q/use CPANPLUS::Backend/, !$@)) {
        print "Fetch: CPAN+\n";
        }
    elsif ($info{fetch} eq "cpan" && (eval q/use CPAN 0.59/, !$@)) {
        print "Fetch: CPAN\n";
        }
    else {
        print "Fetch: HTTP\n";
        $info{fetch} = "web";
        }

    $info{get_mod} = $cpan{$info{fetch}};

    # set requirements patch override

    $ENV{CPAN2RPM} = 1;
    $ENV{CPAN2RPM_REQ_ALL} = $info{"req-scan-all"} || "";

    if ($< && $info{install}) {
        print "NON ROOT install requires sudo rpm privileges\n";
        if (system("sudo rpm --version > /dev/null")) {
            my $msg = "sudo failed, cannot use --install option!  You can\n";
            $msg .= "configure sudo with the following command:\n\n";
            $msg .= "  echo \"".getlogin()." ALL=/bin/rpm\" >> /etc/sudoers";
            die "\n$msg\n\nStopped";
            }

        print "sudo precheck successful\n";
        }

    $info{"make-no-test"} = 1 if $info{"no-depchk"};

    if ($info{modules}) {
        local $_ = $info{modules};
        die "Module list file does not exist!" unless -e;
        die "Cannot read module list file!" unless -r;
        for (split $/, readfile()) {
            s/#.*//;
            push @ARGV, $_ unless /^\s*$/;
            }
        }

    syntax(\%desc, "No distribution specified!")
        unless @ARGV;
    }

#
#   returns hash of info or ref to it in scalar mode
#

sub get_mod {
    my %ret = %info;
    $ret{dist} = shift || $_ || die "get_mod(): no args!";
    $ret{dist} = $CWD if $ret{dist} eq ".";

    print "\n-- module: $ret{dist} --\n";

    #
    #    a url was passed
    #

    if (isurl($ret{dist})) {
        $ret{tarball} = write_url($RPMDIR{SOURCES}, $ret{dist})
            || die "Unable to retrieve tarball";
        push @{$ret{source}}, $ret{dist};
        }

    #
    #    argument passed is a local file name
    #

    elsif (istarball($ret{dist}, 1)) {
        cp($ret{dist}, $RPMDIR{SOURCES})
            || die "get_mod(): cp [$ret{dist}] - $!"
            ;
        ($ret{tarball} = $ret{dist}) =~ s|.*/||;
        }

    #
    #   argument passed is a directory
    #

    elsif (-d $ret{dist}) {
        chdir $ret{dist};
        }

    #
    #    assume argument passed is a Perl module name
    #

    else {
        $ret{tarball} = $ret{get_mod}(\%ret);
        }

    local $_ if defined wantarray();
    $_ = wantarray() ? %ret : \%ret;
    }

sub get_meta {
    my $info = shift || $_; local $_;
    my $pod = Pod::Text->new();

    print "Metadata retrieval\n";

    #    extract tarball

    unless (-d ($info->{evaldir} = $info->{dist})) {
        my $f = "$RPMDIR{SOURCES}/$info->{tarball}";
        print "Tarball extraction: [$f]\n";
        $info->{evaldir} = untar($f);
        }

    eval "use File::Find";
    if ($@) {
        local $_ = "Cannot automatically determine architecture for\n";
        $_ .= "package - defaulting to %_arch macro (this value\n";
        $_ .= "may be overridden with the --buildarch parameter.\n";
        $_ .= "Please install File::Find to allow for automatic\n";
        $_ .= "arch selection.";
        $_ .= "\n$@" if $info->{debug};
        print;
        }
    else {
        my $xs = 0;
        find(sub { $xs = 1 if /\.(xs|c)$/i }, $info->{evaldir});
        $info->{buildarch} = "noarch" if $xs == 0;
        }

    chdir $info->{evaldir} || die "get_meta(): $!";

    $_ = "$info->{evaldir}/Build.PL";
    $_ = "$info->{evaldir}/Makefile.PL" unless -e;
    die qq/No PL file [$_] in tarball/ unless -e;
    die qq/Cannot read PL file [$_]/ unless -r;

    ($info->{PL} = $_) =~ s|.*/||;

    #   we want to protect us from exit()ing but without modifying the
    #   actual Makefile.PL since we may be operating in a source directory

    my $PL = readfile();
    $PL =~ s/\bexit\b/return/gs;
    my $t = "$info->{evaldir}/PL.$$";
    writefile($t, $PL);

    #   now we get the arguments passed to the method that creates
    #   the make script (WriteMakefile || create_build_script)

    {
    no warnings;

    #   dynamically load the module (so when the PL file loads it
    #   we already own it and have hijacked the appropriate method

    my $PLMOD = "ExtUtils::MakeMaker";
    if ($info->{PL} =~ /^Build/) {
        $PLMOD = "Module::Build"; 
        # Module::Build builds itself using itself
        # but we don't have $info->{name} yet, so we use the tarball name
        unshift @INC, 'lib' if $info->{tarball} =~ /^Module-Build/;
        }
    $@ = ""; eval "use $PLMOD"; die "$PLMOD unloadable\n $@" if $@;

    # grab parameters to function e.g. WriteMakefile()

#    my $PLFN = "ExtUtils::MakeMaker::WriteMakefile";
#    $PLFN = "Module::Build::new" if $info->{PL} =~ /^Build/;

#    eval qq/*${PLFN}_orig = \\&$PLFN/;
#    eval qq/*$PLFN = sub {
#        die "SAFETY ABORT!" if \$ENV{_DEEP_RECURSION}++ > 10;
#        %meta = \@_ unless %meta;
#        *$PLFN = \\&${PLFN}_orig;
#        goto &$PLFN;
#        };/;

    my $PLFN;						# TRW vvvv
    if ($info->{PL} =~ /^Build/) {
	$PLFN = "Module::Build::new";
	eval qq/*${PLFN}_orig = \\&$PLFN/;
	eval qq/*$PLFN = sub {
	    die "SAFETY ABORT!" if \$ENV{_DEEP_RECURSION}++ > 10;
	    %meta = \@_[1 .. \$#_] unless %meta;
	    *$PLFN = \\&${PLFN}_orig;
	    goto &$PLFN;
	    };/;
    } else {
	$PLFN = "ExtUtils::MakeMaker::WriteMakeFile";
	eval qq/*${PLFN}_orig = \\&$PLFN/;
	eval qq/*$PLFN = sub {
	    die "SAFETY ABORT!" if \$ENV{_DEEP_RECURSION}++ > 10;
	    %meta = \@_ unless %meta;
	    *$PLFN = \\&${PLFN}_orig;
	    goto &$PLFN;
	    };/;
    }							# TRW ^^^^

    local @ARGV = ();
    local $0 = $t;
    push @ARGV, $info->{"make-maker"} if $info->{"make-maker"};
    # no input or output
    std_close();
    # execute the makefile
    my $ok = 0;
    eval {
        do $t; $ok++;
        };
    my $err = $@;
    # clean up
    std_restore();
    unlink $t || die "get_meta(): rm[$t] - $!";
    if (!$ok) {
        $err =~ s/$t/$info->{PL}/g;
        die "FATAL CRASH! Could not load $info->{PL}:\n$err";
        }
print "start of meta\n";
while(my ($key,$value) = each(%meta))
{
	print "\n$key -- $value\n\n";
}


    #   map Build.PL hash keys to MakeMaker's

    if ($info->{PL} =~ /^Build/) {
        my %b2m = qw/
            requires PREREQ_PM
            module_name NAME
            dist_author AUTHOR
            dist_version VERSION
            dist_version_from VERSION_FROM
	    dist_abstract ABSTRACT
	    dist_name DISTNAME
            rpm_pre RPM_PRE
            rpm_post RPM_POST
            /;
        $meta{$b2m{$_}} = $meta{$_} for keys %b2m;
        }
    }

    #   make sure dependencies are installed

    my @deps;
    my $deps = $meta{PREREQ_PM};
    for (keys %$deps) {
        my $use = "use $_";
	print "Requries: $_ Version: ".$deps->{$_}."\n";

	#MS 1/9/09 
	$info->{"perl-requires"}{$_} = $deps->{$_};

	if ( $deps->{$_} ) {
		my $version = $deps->{$_};
		$version =~ s/^\D+//g;
		print "Checking version:".$version."\n" if $version;
		$use .= " $version" if $version;
	}
#        $use .= " $deps->{$_}" if $deps->{$_};

        local $^W = 0;
        $@ = ""; eval $use;

        push @deps, "$_ >= $deps->{$_}" if $@;
        }
    my $msg = "Unable to build module, the following dependencies have failed:";
    die "$msg\n  " . join("\n  ", @deps) . "\nStopped"
        if @deps && !$info->{"no-depchk"};
    print "Dependency check skipped (--make-no-test implied)\n"
        if $info->{"no-depchk"};

    #   figure out package name

    $info->{module} ||= $meta{DISTNAME} || $meta{NAME};
    if (!$info->{module}) {
        #   for directories, guess at the tarball name
        if (-d $info->{dist}) {
            ($info->{tarball} = $info->{dist}) =~ s|.*/||;
            # a source directory may include a version #
            $info->{tarver} = $info->{tarball} =~ s/-(\d+\.?\d*)$// ? $1 : "";
            }
        $info->{module} = $info->{tarball};
        $info->{module} =~ s/-(\d+\.?\d*)$tarRE$//i;
        $info->{module} =~ s/-/::/g;
        }

    ($info->{name} = $info->{module}) =~ s/::/-/g unless $info->{name};
    $info->{tarball} = $info->{name} if -d $info->{dist};

    die "No package name available.  Stopped"
        unless $info->{name};

    #   get module description info

    my $from = $meta{ABSTRACT_FROM} || $meta{VERSION_FROM};
    ($from = "$info->{module}.pm") =~ s/.*:// unless $from;
    $from = readfile($from);

    $meta{ABSTRACT} ||= "";
    if (!$meta{ABSTRACT} && $from) {
        $meta{ABSTRACT} = $pod->interpolate($1)
            if $from =~ /=head\d\s+NAME.*?-\s*(.*?)$/ism;
        }

    $meta{DESCRIPTION} ||= "";
    if (!$meta{DESCRIPTION} && $from) {
        if ($from =~ /=head\d\s+DESCRIPTION\s+(.*?)=(head|cut)/ism) {
            $meta{DESCRIPTION} = $pod->interpolate($1)
            }
        elsif ($from =~ /=head\d\s+SYNOPSIS\s+(.*?)=(head|cut)/ism) {
            $meta{DESCRIPTION} = $pod->interpolate($1)
            }
        }

        $info->{pre} ||= $meta{RPM_PRE} || "";
        $info->{post} ||= $meta{RPM_POST} || "";


    $info->{author} ||= $meta{AUTHOR} || "";

    if (!$info->{author} && $from =~ /=head\d\s+AUTHORS?\s+(.*?)=/is) {
        local $_ = $1;
        my ($em) = /(\S+(@|\sat\s)\S+)/is;
        $em ||= "";
        $em =~ s/\.$//;             # e.g. Erick Calder e@arix.com.
        ($_) = /((?:\S+\s+){1,3})\Q$em\E/is;
        $_ ||= "";
        s/[^a-zA-Z ]+//g;           # Peter Behroozi, behroozi@www.pls.uni.edu
        trim(); s/\s+/ /g;
        $em =~ s/\s+at\s+/@/g;
        $em =~ s/[()<>]//g;           # Eryq (eryq@zeegee.com)
        $_ .= " <$em>";
        s/E<(lt|gt)>//ig;           # Erick Calder E<lt>e@arix.comE<gt>
        $info->{author} = $_;
        }

    if (!$info->{author}) {
        # Extract generic author from any of the urls
        for (@{$info->{source}}) {
            if (isurl() && m%author.*/([A-Z\-]+)/[^/]+$%) {
                $info->{author} = (lc $1).'@cpan.org';
                last;
                }
            }
        }

    die "No author information found, please use --author option.  Stopped"
        unless $info->{author};

    #   extract version

    $info->{version} ||= $meta{VERSION};
    unless ($info->{version}) {
	require ExtUtils::MakeMaker
		unless ExtUtils::MM_Unix->can ('parse_version');
        $info->{version} = ExtUtils::MM_Unix->parse_version($from)
            if $from = $meta{VERSION_FROM};
        trim($info->{version}); # parse_version() returns spaces
        }
    $info->{version} ||= $info->{tarver};

    die "No version found, please use --version option.  Stopped"
        unless $info->{version};

    #   refix all macro dirs for %name, %version

    chkdirs();

    $info->{spec} ||= "$RPMDIR{SPECS}/$info->{name}.spec";
    ($info->{tardir} = $info->{evaldir}) =~ s|.*/||;

    #   for directories, guess some of the needed values

    if (-d $info->{dist}) {
        ($info->{tardir} = $info->{module}) =~ s|::|-|g;
        $info->{tardir} .= "-$info->{version}"
            unless $info->{tardir} =~ /-(\d+.*)$/;
        $info->{tarball} = "$info->{tardir}.tar.gz";
        }

    #   tarballs without a subdir need one created

    $info->{create} = $info->{tardir} =~ s/\+$// ? "-c" : "";

    #    create file-list for spec's %doc section

    my %doc;
    for (split $/, readfile("MANIFEST")) {
        s|[/\s].*||;
        # get subdirs (with some exceptions)
        $doc{$_} = 1, next if -d && !/^(t|lib|bin|etc)$/;
        # list all files that match the regexp
        $doc{$_} = 1 if /$docRE/i;
        }
    $info->{doc} ||= "";
    $info->{doc} = join " ", $info->{doc}, keys %doc
        unless $info->{doc} =~ s/^=//;
    $info->{doc} &&= "%doc $info->{doc}";

    my $config_path = "";
    $config_path = $meta{install_path}{etc} if exists($meta{install_path}{etc});
    print "Config Path: $config_path\n";
    my %etc;
    for (split $/, readfile("MANIFEST")) {
        s|[\s].*||;
        # list all files that match the regexp
        print "Config Match: $1\n" if /^etc(.*)/i;
	$etc{"%config(noreplace) $config_path$1"} = 1 if /^etc(.*)/i;
        }
    $info->{etc} ||= "";
    $info->{etc} = join "\n", $info->{etc}, keys %etc
        unless $info->{etc} =~ s/^=//;

print "Info etc = ".$info->{etc}."\n";
#    $info->{etc} &&= "%config(noreplace) %{_sysconfdir}/ $info->{etc}";

    #   fixes the #! so perl can be found (and deps get made ok)

    $info->{fixin} = <<EOF;
        grep -rsl '^#!.*perl' . |
        grep -v '\.bak\$' |xargs --no-run-if-empty \\
        %__perl -MExtUtils::MakeMaker -e 'MY->fixin(\@ARGV)'
EOF

    #    assemble other info

    $info->{summary} = "$info->{name} - " . ($meta{ABSTRACT} || "Perl module");
    $info->{description} = $meta{DESCRIPTION} if $meta{DESCRIPTION};
    push @{$info->{source}}, $info->{tarball}
        unless $info->{source};
    $info->{changelog} = changelog();

    $info->{"find-provides"}
        &&= qq/%define __find_provides $info->{"find-provides"}/;
    $info->{"find-requires"} &&= qq/
        %define __find_requires $info->{"find-requires"}\n
        %define __perl_requires $info->{"find-requires"}
        /;

    #   option lists

    $info->{"opts-simple"} = [qw/
        name summary version release epoch
        vendor packager distribution license group url
        buildroot buildarch
        /];

    $info->{"opts-agg"} = [qw/
        provides requires buildrequires source patch
        /];

    $info->{"opts-secs"} = [qw/
        prep build install clean changelog tag files
        /];

    #   handle aggregate options

    $info->{"$_-list"} = optagg($info) for @{$info->{"opts-agg"}};
    $info->{"define-list"} .= "";
    foreach (@{$info->{"define"}}) {
      if (/^(\w)=(.*)/) {
          $info->{"define-list"} .= "%define $1 $2\n";
          }
      else {
          $info->{"define-list"} .= "%define $_\n";
          }
      }
    #   section handlers

    my $prologue = $info->{prologue};
    delete $info->{prologue};
    for (@$prologue) {
        /^(\w+):(.*)$/ || next;
        my ($sec, $v) = ($1, $2);
        $info->{prologue}{$sec} = $v . $/;
        }

    my $epilogue = $info->{epilogue};
    delete $info->{epilogue};
    for (@$epilogue) {
        /^(\w+):(.*)$/ || next;
        my ($sec, $v) = ($1, $2);
        $info->{epilogue}{$sec} = $v . $/;
        }

    for (@{$info->{"opts-secs"}}) {
        $info->{prologue}{$_} ||= "";
        $info->{epilogue}{$_} ||= "";
        }

    #   special situations

    if ($info->{"no-requires"}) {
        my $noreqs = "";
        for (@{$info->{"no-requires"}}) {
            $noreqs .= qq/-e '$_' / for split /\s*,\s*/;
            }
        delete $info->{"no-requires"};
        $info->{"no-requires"}{"define"}
            = "%define custom_find_req %{_tmppath}/%{NVR}-find-requires";
        $info->{"find-requires"}
            = "%define _use_internal_dependency_generator 0";
        $info->{"find-requires"}
            .= "\n%define __find_requires %{custom_find_req}";
        $info->{"find-requires"}
            .= "\n%define __perl_requires %{custom_find_req}";
        local $_ = qq[cat <<EOF > %{custom_find_req}
            #!/bin/sh
            /usr/lib/rpm/find-requires |grep -v $noreqs
            EOF
            chmod 755 %{custom_find_req}
            ];
        s/^\s+//mg;
        $info->{"no-requires"}{"install"} = $_;
        $info->{"no-requires"}{"clean"} = "rm -f %{custom_find_req}";
        }

    $info->{"no-requires"}{"define"} ||= "";
    $info->{"no-requires"}{"install"} ||= "";
    $info->{"no-requires"}{"clean"} ||= "";

    # fix patch info

    my $i = 0;
    $info->{"patch-files"} = "";
    $info->{"patch-apply"} = "";

    for (split $/, $info->{"patch-list"}) {
        s/.*:\s+//;
        $info->{"patch-files"}
            .= sprintf("%-*s %s\n", $SPECCOL, "Patch$i:", $_);
        $info->{"patch-apply"} .= "%patch$i -p1\n";
        # put patches in RPM dir if needed
        cp($_, $RPMDIR{SOURCES})
            || die "Unable to copy patch [$_]: $!";
        $i++;
        }

    # return to user's directory

    chdir $CWD;
    }

#
#    generate s spec file
#

sub mk_spec {
    my $info = shift || $_; local $_;

    print "Generating spec file\n";

    # clean warnings about missing keys

    $info->{$_} ||= "" for keys(%info), @{$info->{"opts-simple"}};
    $info->{$_} ||= "" for qw/make fixin/;    # extra tags
    $info->{"$_-list"} ||= "" for @{$info->{"opts-agg"}};

    # strip ctrl-M's from Windoze files

    $info->{$_} =~ s/\r//g for keys %info;

    # generalise whenever possible

    for (qw/tardir source/) {
        $info->{$_} =~ s/$info->{name}/%{pkgname}/;
        $info->{$_} =~ s/$info->{version}/%{version}/;
        }

    $info->{description} =~ s/\s+$//;
    $info->{maketest} = $info->{"make-no-test"} ? 0 : 1;
    $info->{vendor} = $info->{author};

    if ($info->{name} eq "ExtUtils-MakeMaker") {
        # MakeMaker builds itself using itself
        $ENV{PERL5LIB} = $ENV{PERL5LIB}?"lib:$ENV{PERL5LIB}":"lib";
        }

    # Versions between 5.91 and 6.05 need PREFIX= on Makefile.PL line

    my $perl = q/`%%{__perl} -MExtUtils::MakeMaker -e '%s'`/;
    my $mm_maker = q#
        print qq|PREFIX=%{buildroot}%{_prefix}|
            if \\$ExtUtils::MakeMaker::VERSION =~ /5\.9[1-6]|6\.0[0-5]/
        #;
    $mm_maker =~ s/\s+/ /gs;
    $info->{"make-maker"} ||= sprintf($perl, $mm_maker);

    # Versions before 5.91 need PREFIX= on install line
    # Versions after 6.05 need DESTDIR= on install line

    my $mm_install = q#
        print \\$ExtUtils::MakeMaker::VERSION <= 6.05
            ? qq|PREFIX=%{buildroot}%{_prefix}|
            : qq|DESTDIR=%{buildroot}|
        #;
    $mm_install =~ s/\s+/ /gs;
    $info->{"make-install"} ||= sprintf($perl, $mm_install);

    $info->{"make-install"} = "destdir=%{buildroot}"
        if $info->{PL} =~ /^Build/;

    if ($info->{"shadow-pure"}) {
        # Force pure perl installs into first @INC slot
        $info->{"make-maker"} .= sprintf("; %%{__perl} -pi -e '%s' Makefile",
            q|s/^(INSTALL[PVS]\w+LIB =).*/$1 \$(INSTALLARCHLIB)/|
            );

        # Avoid man page conflicts with default
        $info->{"make-maker"} .= sprintf("; %%{__perl} -pi -e '%s' Makefile",
            q|s,(INSTALLMAN3DIR =[^/]+)/.*,$1/man/man3,|
            );
        }

    # prepend string to separate module from usual namespace

    my $pkgname = $info->{name};
    $info->{name} = "perl-" . $info->{name} unless $info->{"no-prfx"};

    my $spec = <<ZZ;
        #
        #   - $info->{module} -
        #   This spec file was automatically generated by cpan2rpm [ver: $VERSION]
ZZ
    my $me; ($me = $0) =~ s|.*/||;
    $spec .= <<ZZ unless $info->{module} eq $me;
        #   The following arguments were used:
        #       $ARGS
ZZ
    $spec .= <<ZZ;
        #   For more information on cpan2rpm please visit: http://perl.arix.com/
        #

        %define pkgname $pkgname
        %define filelist %{pkgname}-%{version}-filelist
        %define NVR %{pkgname}-%{version}-%{release}
        %define maketest $info->{maketest}
ZZ
    $spec .= <<ZZ if $info->{"define-list"};
        # user definitions
        $info->{"define-list"}
ZZ
    $spec =~ s/^[^\S\n]+//mg;

    $spec .= $info->{"no-requires"}{"define"} . $/
        if $info->{"no-requires"}{"define"};
    $spec .= $info->{"find-provides"} . $/
        if $info->{"find-provides"};
    $spec .= $info->{"find-requires"} . $/
        if $info->{"find-requires"};

    #   add simple tags

    $spec .= "\n";
    for (@{$info->{"opts-simple"}}) {
        $spec .= sprintf("%-*s %s\n", $SPECCOL, "$_:", $info->{$_})
            if $info->{$_};
        }

    $spec .= sprintf("%-*s %s\n", $SPECCOL, "prefix:", "%(echo %{_prefix})");

    #   add lists

    for (keys %{$info->{"perl-requires"}}) {
        $spec .= sprintf("%-*s perl(%s)", $SPECCOL, "requires: ", $_);
        if($info->{"perl-requires"}{$_}) {
	    if($info->{"perl-requires"}{$_} =~m/^\s?[<>=!]+\s?\d+/g) {
                $spec .= " ".$info->{"perl-requires"}{$_};
            } elsif ($info->{"perl-requires"}{$_} =~m/^\s?\d+/g) {
                $spec .= " == ".$info->{"perl-requires"}{$_};
            }
        }
        $spec .="\n";
    }


    $spec .= $info->{"provides-list"};
    $spec .= $info->{"requires-list"};
    $spec .= $info->{"buildrequires-list"};
    $spec .= $info->{"source-list"};
    $spec .= $info->{"patch-files"};
    $spec .= $info->{epilogue}{tag};
    if($info->{"no-auto-prov"}) {
        $spec .= "AutoProv: no\n";
    }	
    $spec .= "\n" . q/%description/ . "\n$info->{description}\n";

    $_ = <<ZZ;

        #
        # This package was generated automatically with the cpan2rpm
        # utility.  To get this software or for more information
        # please visit: http://perl.arix.com/
        #
ZZ
    s/^[^\S\n]+//mg; $spec .= $_;

    #   handle sections

    $_ = "%setup -q -n $info->{tardir} $info->{create}";
    $_ .= $/ . $info->{'patch-apply'}
        if $info->{"patch-apply"};
    $_ .= $/ . "chmod -R u+w %{_builddir}/$info->{tardir}" . $/;
    $spec .= mksec($info, "prep" => $_);

    $_ = ($info->{PL} =~ /^Make/)
        ? qq/
            $info->{fixin}
            CFLAGS="\$RPM_OPT_FLAGS"
            %{__perl} Makefile.PL $info->{"make-maker"}
            %{__make} $info->{"make"}
            %if %maketest
                %{__make} test
            %endif
        / : qq/
            $info->{fixin}
            %{__perl} Build.PL
            %{__perl} Build
            %if %maketest
                %{__perl} Build test
            %endif
        /;
    s/^\s+//mg;
    $spec .= mksec($info, "build" => $_);

    my $install = ($info->{PL} =~ /^Make/)
        ? qq/%{makeinstall} /
        : qq/%{__perl} Build install /
        ;
    $install .= $info->{"make-install"};

    $_ = <<ZZ;
        [ "%{buildroot}" != "/" ] && rm -rf %{buildroot}
        $info->{"no-requires"}{"install"}
        $install

        cmd=/usr/share/spec-helper/compress_files
        [ -x \$cmd ] || cmd=/usr/lib/rpm/brp-compress
        [ -x \$cmd ] && \$cmd

        # SuSE Linux
        if [ -e /etc/SuSE-release -o -e /etc/UnitedLinux-release ]
        then
            %{__mkdir_p} %{buildroot}/var/adm/perl-modules
            %{__cat} `find %{buildroot} -name "perllocal.pod"`  \\
                | %{__sed} -e s+%{buildroot}++g                 \\
                > %{buildroot}/var/adm/perl-modules/%{name}
        fi

        # remove special files
        find %{buildroot} -name "perllocal.pod" \\
            -o -name ".packlist"                \\
            -o -name "*.bs"                     \\
            |xargs -i rm -f {}

        # no empty directories
        find %{buildroot}%{_prefix}             \\
            -type d -depth                      \\
            -exec rmdir {} \\; 2>/dev/null

        %{__perl} -MFile::Find -le '
            find({ wanted => \\&wanted, no_chdir => 1}, "%{buildroot}");
            print "$info->{doc}";
            print <<ETC; $info->{etc} 
ETC

            for my \$x (sort \@dirs, \@files) {
                push \@ret, \$x unless indirs(\$x);
                }
            print join "\\n", sort \@ret;

            sub wanted {
                return if /auto\$/;

                local \$_ = \$File::Find::name;
                my \$f = \$_; s|^\\Q%{buildroot}\\E||;
                return unless length;
                return \$files[\@files] = \$_ if -f \$f;

                \$d = \$_;
                /\\Q\$d\\E/ && return for reverse sort \@INC;
                \$d =~ /\\Q\$_\\E/ && return
                    for qw|/etc %_prefix/man %_prefix/bin %_prefix/share|;

                \$dirs[\@dirs] = \$_;
                }

            sub indirs {
                my \$x = shift;
                \$x =~ /^\\Q\$_\\E\\// && \$x ne \$_ && return 1 for \@dirs;
                }
            ' > %filelist

        [ -z %filelist ] && {
            echo "ERROR: empty %files listing"
            exit -1
            }
ZZ
    s/^ {8}//mg;
    $spec .= mksec($info, "install" => $_);

    $_ = qq|[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}\n|;
    # $_ .= qq|rm -rf %_builddir/%name-%version\n|;
    $_ .= qq/$info->{"no-requires"}{"clean"}\n/
        if $info->{"no-requires"}{"clean"};
    $spec .= mksec($info, "clean" => $_);

    $spec .= qq|$/%files -f %filelist|;
    $spec .= qq|$/%defattr($info->{defattr})$/|;

    if($info->{post})
    {
        $spec .= qq|$/%post\n$info->{post}$/|;
    }

    if($info->{pre})
    {
        $spec .= qq|$/%pre\n$info->{pre}$/|;
    }

    $spec .= $info->{epilogue}{files};

    $spec .= mksec($info, "changelog"
        => "* $info->{changelog}\n- Initial build."
        );

    writefile($info->{spec}, $spec);
    print("SPEC: $info->{spec}\n");
    exit if $info->{"spec-only"};
    }

#
#    build the package
#

sub mk_rpm {
    my $info = shift || $_; local $_;

    if (-d $info->{dist}) {
        system("perl Makefile.PL && make") == 0 || die "mk_rpm(): $!"
            unless ($info->{name} eq "cpan2rpm");
        system("make dist") == 0 || die "mk_rpm('make dist'): $!";

        cp($info->{tarball}, $RPMDIR{SOURCES})
            || die "mk_rpm(): cp [$info->{tarball}] - $!"
            ;
        }

    $info->{rpm} = sprintf("%s/%s-%s-%s.%s.rpm"
        , "$RPMDIR{RPMS}/$info->{buildarch}"
        , $info->{name}
        , $info->{version}
        , $info->{release}
        , $info->{buildarch}
        );
    $info->{srpm} = sprintf("%s/%s-%s-%s.src.rpm"
        , $RPMDIR{SRPMS}
        , $info->{name}
        , $info->{version}
        , $info->{release}
        );

    my $ret = 0;
    if (! -r $info->{rpm} || $info->{force}) {
        print "Generating package\n";

        my $bp = qx/$RPM -bp $info->{spec} 2>&1/;
        warn("RPM test unpacking failed! [$RPM -bp $info->{spec}]\n$bp")
            if $ret = $? >> 8;

        if ($ret == 0) {
            my @cmd = ($RPM, '-ba');
            push @cmd, "--clean" unless $info->{"no-clean"};
            push @cmd, $info->{sign} if $info->{sign};
            push @cmd, $info->{spec};
            debug(join " ", @cmd);
            print "Signing package (pass phrase required)\n"
                if $info->{sign};
            system(@cmd);
            die "RPM build failed [$ret]" if $ret = $? >> 8;
            }
        }

    print "RPM: $info->{rpm}\n" if -r $info->{rpm};
    print "SRPM: $info->{srpm}\n" if -r $info->{srpm};
    return $ret;
    }

#
#    if requested, will also install the resulting RPM
#

sub inst_rpm {
    my $info = shift || $_; local $_;
    return unless $info->{install};

    print "Installing package\n";
    my @cmd = (qw/rpm -Uvh/, $info->{rpm});
    unshift @cmd, "sudo" if $<;
    system(@cmd);
    return $? >> 8;
    }

# --- module retrieval functions ----------------------------------------------

sub get_cpan_plus {
    my $info = shift;
    my $cp = CPANPLUS::Backend->new();

    print "Retrieving remote information\n- module\n";
    my $m = $cp->search(
        type => 'module', list => ["^$info->{dist}\$"]
        );
    $m = $m->{$info->{dist}}; # finds multiple packages
    $info->{tarball} = $m->{package};
    $info->{version} = $m->{version};

    print "- author\n";
    my $a = $cp->search(
        type => 'author', list => ["^$m->{author}\$"], authors_only => 1
        );
    $a = $a->{$m->{author}}; # finds multiple authors
    $info->{author} ||= "$a->{name} <$a->{email}>";

    my $f = $m->{path} . "/" . $m->{package};
    push @{$info->{source}}, $f;
    debug("CPAN meta: author=$info->{author}, f=$f");

    # bail if tarball already there (unless we're being --force'd)
    if (-s "$RPMDIR{SOURCES}/$info->{tarball}"
        && -r _
        && ! defined $info->{force}) {
        print "Tarball found - not fetching\n";
        return $info->{tarball};
        }

    print "Fetching module\n";
    my $rc = $cp->fetch(
        modules => [$info->{dist}], fetchdir => $RPMDIR{SOURCES}
        );
    die "Failed fetching tarball.  Stopped"
        unless $rc->{ok};
    
    $info->{tarball};
    }

#
#    grabs the module from CPAN and places in the SOURCES directory
#    ACHTUNG: at present, only the latest version of the module
#    can be retrieved.  For building earlier versions, retrieve the
#    tarball manually.
#

sub get_cpan_old {
    my $info = shift;

    my $m = CPAN::Shell->expand("Module", $info->{dist})
        || die "Module not found on CPAN!";

    # somewhere between CPAN version 1.52 and 1.65 the interface
    # changed, moving all relevant data to the RO key

    $m = $m->{RO} if $m->{RO};
    $info->{version} ||= $m->{CPAN_VERSION};

    my $a = CPAN::Shell->expand("Author", $m->{CPAN_USERID});
    $a = $a->{RO} if $a->{RO};

    $info->{author} ||= "$a->{FULLNAME} <$a->{EMAIL}>";
    $info->{f} = $m->{CPAN_FILE};

    push @{$info->{source}}, "http://search.cpan.org/dist/" .  $info->{f};

    debug("CPAN meta: author=$info->{author}, f=$info->{f}");

    # bail if tarball already there (unless we're being --force'd)
    my $tarball = $info->{f}; $tarball =~ s|.*/||;
    if (-s "$RPMDIR{SOURCES}/$tarball" && -r _ && ! defined $info->{force}) {
        print "Tarball found - not fetching\n";
        return $tarball;
        }

    get($info->{f});

    $CPAN::Config->{'keep_source_where'} ||= "UNKNOWN";
    my $ff = sprintf("%s/authors/id/%s"
        , $CPAN::Config->{'keep_source_where'}
        , $info->{f}
        );

    debug("ff=$ff");
    system("cp", $ff, $RPMDIR{SOURCES}) if -r $ff;
    $ff =~ s|.*/||;
    $info->{tarball} = $ff;
    }

#
#   - Walks search.cpan.org for the latest uploaded distribution
#   - Uses LWP instead of CPAN to determine the tarball
#   - on failure, returns url passed in
#

sub get_cpan_web {
    my $info = shift;
    my $url;

    my $cache = "$RPMDIR{SOURCES}/$info->{dist}";
    if (!$info{force} && ($url = readlink($cache))) {
        print "Using cached URL: $url\n";
        }
    else {
        my $base = "http://search.cpan.org";
        $url = "$base/dist/$info->{dist}"; $url =~ s/::/-/g;

        # XXX - this algorithm may change as the
        # search.cpan.org web site output changes.

        local $_ = http_get($url) || return;
        m% \<a[^<>]*         # Begin Anchor tag
            href\s*=\s*       # href parameter
            (['"]?)           # Maybe quote
            ([^<>\s"']*)      # Extract link as $2
            \1                # Maybe quote
            [^<>]*\>          # End Anchor tag
            \s*Download       # of the "Download" link
            %ix;              # case insensitive HTML

        die "Module not found on CPAN web site!"
            unless $2;

        $url = "$base/$2";
        my ($loc, $fn) = $url =~ m|(.*)/(.*)|;
        print "Found: $fn\nAt: $loc\n";
        unlink($cache) if -l $cache;
        symlink($url, $cache);
        }

    $info->{f} = $url;

    # bail if tarball already there (unless we're being --force'd)
    my $tarball = $info->{f}; $tarball =~ s|.*/||;
    if (-s "$RPMDIR{SOURCES}/$tarball" && -r _ && ! defined $info->{force}) {
        print "Tarball found - not fetching\n";
        return $tarball;
        }

    push @{$info->{source}}, $info->{f};
    $info->{tarball} = write_url($RPMDIR{SOURCES}, $info->{f})
            || die "Unable to retrieve tarball";
    }

# --- tar handling functions --------------------------------------------------

#
#    determines whether given filename represents a tarball
#    optionally dies it file doesn't exist or is not readable
#

sub istarball {
    my ($fn, $fschk) = @_;
    my $is = $fn =~ /$tarRE/i;
    return $is unless $fschk && $is;
    -r $fn || die "tarball: $!";
    }

sub ls {
    my $d = shift || $_;
    opendir(DIR, $d) || die "ls(): $!";
    my @f = grep { !/^\.\.?$/ } readdir(DIR);
    closedir(DIR);
    ($d, @f);
    }

#
#    extracts a tarball
#

sub untar($) {
    local $_ = shift;
    my $dst = shift || $TMPDIR;
    my $zip = /\.zip$/;

    my $z = /\.tar\.bz2$/i ? "j" : "z";
    my @cmd = (qw/tar -x --directory/, $dst, "-$z", "-f", $_);
    @cmd = (qw/unzip -d/, $dst, $_) if /\.zip$/i;
    system(@cmd) == 0 || die "system @cmd failed: $?";
    system("chmod", "-R", "u+w", $dst);

    my $cmd = $zip
        ? "unzip -l $_ | grep -P -o '\\S+/\$' |tail -1"
        : "tar -t${z}vf $_ |head -1"
        ;

    chomp($_ = qx/$cmd/);
    $_ = (split)[5] unless $zip;
    $dst .= "/$1" if m|^(\S+)/|;
    $dst =~ s|/*$||;    # path shouldn't end in / or tardir gets wiped
    $dst =~ s|\./||;    # paths in tarballs shouldn't be relative
    return $dst;
    }

# --- file handling functions -------------------------------------------------

#
#   returns the contents of a given file or undef if the
#   file does not exist.  if no filename is passed $_ is used.
#   when called in void context, sets $_
#

sub readfile {
    my $f = shift || $_;
    local $_ if defined wantarray();

    return $_ = "" unless -r $f;

    local $/ = undef;
    open(F, $f) || die "$! [$f].  Stopped ";
    $_ = <F>;
    close(F);
    $_;
    }

#
#    writes a file, from a string
#

sub writefile($@) {
    my $fn = shift;
    local $_ = shift || $_;
    my $op = shift || ">";

    open (FILE, "$op $fn") || die "writefile('$fn'): $!. Stopped";
    binmode(FILE);
    print FILE;
    close FILE || die "writefile('$fn'): $!. Stopped";
    $fn;
    }

sub cp {
    my ($f, $d, $ff) = @_;
    $f =~ s/~/$ENV{HOME}/;
    return 1 unless -r $f;
    ($ff = $f) =~ s|.*/||;
    return 1 if finode($f) eq finode("$d/$ff");
    system("cp", "-u", $f, $d) == 0;
    }

#    0: dev, 1: inode, the combination guarantees
#    a unique file in a filesystem

sub finode {
    local $_ = shift || $_;
    my @i; "$i[0]$i[1]" if @i = stat;
    }

#    simple test to determine if it's a URL

sub isurl {
    local $_ = shift || $_;
    scalar m#(ht|f)tp://#;
    }

#    Syntax: content = http_get [url]

sub http_get {
    my $url = shift || $_;

    $HTTPWARN = 1 if $info{dist} =~ /libwww-perl/;

    if ($@ = "", eval "use HTTP::Request::Common; use LWP::UserAgent;", !$@) {
        my $ua = LWP::UserAgent->new();
        return $ua->request(GET($url))->content || "";
        }
    elsif ($HTTPWARN == 0) {
        print "\nWARNING: libwww-perl module not found.  To install, one ";
        print "of the following options may help:\n\n";

        local $\ = $/;
        $url = "http://www.rpmfind.net/linux/rpm2html/search.php";
        $url .= "?query=perl-libwww-perl";
        print "  1) Try $url";
        $url = "http://www.cpan.org/modules/by-module/LWP/";
        $url .= "libwww-perl-5.68.tar.gz";
        print "  2) Specify the full URL of the tarball manually.";
        print "     cpan2rpm -i $url";
        print "  3) Download tarball and specify file on commandline.";
        print "  4) Configure CPAN: perl -MCPAN -eshell";
        print "  5) cpan2rpm -i libwww-perl\n";
        print "Trying HTTP::Lite...";
        }

    if ($@ = "", eval "use HTTP::Lite;", !$@) {
        my $http = HTTP::Lite->new();
        $http->request($url) || die "http_get(): $!.  Stopped";
        return $http->body() || "";
        }
    elsif ($HTTPWARN == 0) {
        print "\nWARNING: this alternative module could not be found ";
        print "either!  Please install the libwww-perl package ";
        print "as indicated above.\n\n";
        print "Trying external programs...\n";
        }

    $HTTPWARN = 1;

    my ($host, $doc) = $url =~ m|tp://(.*?)(/.*)|;
    my @prg = (
        "/usr/bin/lynx -source $url",
        "/usr/bin/links -source $url",
        "/usr/bin/wget -O - $url",
        "/usr/bin/ncftpget $url && cat " . ($url =~ m|.*/(.*)|),
        "echo -e \"user anonymous x\@x.com\nget $doc\" |/usr/bin/ftp -u $host",
        );

    for (@prg) {
        my ($p) = /^(\S+)/;
        next unless -e $p;
        my $ret = qx/$_/;
        print("Retrieving with [", $p =~ m|([^/]+)$|, "]\n"), return $ret
            if $? == 0;
        }

    my $msg = "External program support failed.  Manual download required";
    die "> $msg.\nStopped";
    }

#    Syntax: tarball = write_url <directory> [url]

sub write_url {
    my ($d, $url) = @_;
    $d =~ s|/$||;    # no trailing /s

    $url ||= $_;
    return unless $url;

    my $tar; ($tar = $url) =~ s|.*/||;
    return $tar if -s "$d/$tar" && -r _ && !$info{force};

    print "Retrieving URL\n";
    local $_ = http_get($url);
    return if /^Fail/;    # Failed to establish connection
    return unless $_;

    writefile("$d/$tar");
    return $tar;
    }

sub std_close {
    return if $info{debug} || $info{"keep-pipes"};
    open(OLDOUT, ">&STDOUT")   || die "std_save(): $!";
    open(OLDERR, ">&STDERR")   || die "std_save(): $!";
    open(OLDIN,  "<&STDIN")    || die "std_save(): $!";
    open(STDOUT, ">/dev/null") || die "std_close(): $!";
    open(STDERR, ">/dev/null") || die "std_close(): $!";
    open(STDIN,  "</dev/null") || die "std_close(): $!";
    }

sub std_restore {
    return if $info{debug} || $info{"keep-pipes"};
    open(STDOUT, ">&OLDOUT") || die "std_restore(): $!";
    open(STDERR, ">&OLDERR") || die "std_restore(): $!";
    open(STDIN,  "<&OLDIN")  || die "std_restore(): $!";
    }

sub chkdirs {
    my @dirserr;
    for my $k (keys %RPMDIR) {
        next if $k eq "ARCH";
        local $_ = $RPMDIR{$k};

        # e.g. %_specdir = "%{name}-%{version}"
        my $x = $_;
        s/%{?name?}/$info{name}/i if $info{name};
        s/%{?version?}/$info{version}/i if $info{version};
        mkdir($_, 0755) unless $x eq $_ || -d $_;
        $RPMDIR{$k} = $_;

        next if /%/;    # skip chking in case other tags present
        push @dirserr, $_ unless -d && -w;
        }

    if (@dirserr) {
        print "RPM user environment - Your account does not have\n";
        print "permissions to the requisite RPM directory structure.\n";
        print "Try 'cpan2rpm --mk-rpm-dirs=~/rpm' to setup your\n";
        print "environment for non-root package building.\n";
        print "Failing dirs: ", join(" ", @dirserr), "\n";
        exit(1);
        }
    }

# --- init routines -----------------------------------------------------------

#
#   creates user directories for RPM
#

sub mk_rpm_dirs {
    local $_ = "$ENV{HOME}/.rpmmacros";
    my $topdir = `echo -n $info{"mk-rpm-dirs"}`;
    if (!-e) {
        writefile($_, qq/%_topdir $topdir\n/);
        }
    elsif (-r) {
        my $s = readfile();
        writefile($_, qq/\n%_topdir $topdir\n/, ">>")
            unless $s =~ /topdir/is;
        }

    my @subdirs = qw|
        BUILD SOURCES SPECS SRPMS
        RPMS RPMS/i386 RPMS/i686 RPMS/noarch
        |;
    push @subdirs, "RPMS/$info{buildarch}" if $info{buildarch};
    for (map "$topdir/$_", "", @subdirs) {
        next if -e;
        mkdir($_, 0755) || die "Cannot make $_: $!";
        }

    print "RPM user environment set up.  Your system should be ";
    print "ready for packaging!\n";
    }

#
#   sets up an account for signing packages
#

sub sign_setup {
    my $msg = "Incorrectly formatted argument.  ";
    $msg .=  "Do not pass a module name with this option!\nStopped";
    die $msg unless $info{"sign-setup"} =~ /(^(gpg|pgp):)|^\s*$/i;

    my $mac = "$ENV{HOME}/.rpmmacros"; local $_ = $mac;
    die "Cannot read use macros file" unless -r;

    readfile();
    die "Package signing already set up.\n"
        . "Please edit macros file manually at $mac\n"
        . "Stopped"
        if /%_signature/i;

    # make sure gpg's there
    my $gpg = getrpm_macdef("_gpg");
    $gpg = inpath("gpg") unless -e $gpg;
    $gpg = inpath("pgp") unless -e $gpg;
    die "Neither GPG nor PGP found in PATH.  Stopped"
        unless -e $gpg;
    die "$gpg is not executable!  Stopped" unless -x $gpg;

    my $gpg_path = getrpm_macdef("_gpg_path");
    $gpg_path = "$ENV{HOME}/.gnupg" if $gpg_path eq '%{_gpg_path}';
    my ($type, $usr) = split ":", $info{"sign-setup"};
    $type ||= "gpg";

    my $key = gpgkey();
    $msg = "No keypairs available on your keyring!  Run:\n";
    $msg .= "\n\t# gpg --gen-key\n";
    $msg .= "\nStopped";
    die $msg unless $key;

    $usr ||= $key;

    my @gpg = (
        "%_signature $type",
        "%_gpgbin $gpg",
        "%_gpg_path $gpg_path",
        "%_gpg_name $usr",
        );

    writefile($mac, join($/, "", @gpg, ""), ">>");
    print "Package signing macros set up.\nPlease review $mac\n";
    }

# --- miscellany --------------------------------------------------------------

sub gpgkey {
    for (qx|gpg --list-keys 2> /dev/null|) {
        next unless /^pub/;
        my ($id) = m|/([A-Z0-9]+)\s|;
        return $id;
        }
    }

sub optagg {
    my $info = shift || die "optagg: no info!";
    my $nm = shift || $_;
    my @opt; push @opt, split /,/ for @{$info->{$nm}};
    my $ret = "";
    $ret .= sprintf("%-*s %s\n", $SPECCOL, "$nm:", $_) for @opt;
    $ret;
    }

# returns 404 for 4.0.4 and 420 for 4.2

sub getrpm_ver {
    chomp(local $_ = qx/rpm --version/);
    $_ = (split)[2];
    s/\.//g; $_ *= 10 if $_ < 100;
    $_;
    }

sub getrpm_macdef($) {
    my $key = shift;
    chomp(local $_ = qx/rpm --eval \%{$key}/);
    s/^\s+//; s/\s*\n+/ /gs; s/\s+$//;
    $_;
    }

sub inpath($) {
    my $cmd = shift;
    -x "$_/$cmd" && return "$_/$cmd" for split /:/, $ENV{PATH};
    }

sub mksec {
    my $info = shift;
    my $nm = shift;
    my $ret = qq|$/%$nm|;
    $ret .= "$/$info->{prologue}{$nm}" if $info->{prologue}{$nm};
    $ret .= "$/$_" for @_;
    $ret .= "$/$info->{epilogue}{$nm}" if $info->{epilogue}{$nm};
    $ret;
    }

sub chkupgrade {
    return if defined $info{"no-upgrade-chk"};
    print "Upgrade check\n";

    my $up = "";
    eval {
        alarm(5);
        $SIG{ALRM} = sub {
            die "Network too slow, check elapsed...\n";
            };
        my $mod = $info{dist}; $mod =~ s|.*/||;
        local $_ = "http://perl.arix.com/cpan2rpm/?";
        $_ .= "version=$VERSION&mod=$mod";
        $up = http_get();
        };
    alarm(0);
    return unless $up eq "Y";

    local $\ = $/;
    print "";
    print "* A newer version of this program is now available. To upgrade";
    print "* enter the following command: $0 --upgrade\n";
    }

sub upgrade {
    $info{install}++;
    my $url = http_get("http://perl.arix.com/cpan2rpm/?latest=gz");
    my ($ver) = $url =~ /-(\d+\.\d+)\.t[ar|gz]/;
    die "Upgrade version unclear!" unless $ver;
    print "Upgrading...\nLatest ver: $ver\n";
    unless (write_url($TMPDIR, $url)) {
        local $\ = $/;
        print "\nERROR: Unable to retrieve tarball, please visit our web\n";
        print "site at: http://perl.arix.com/, download the latest version\n";
        print "and refer to the installation instructions in the ";
        print "README file.\n";
        exit(-1);
        }

    my ($f) = $url =~ m|.*/(.*)|;
    my @ret = qx|$RPM -ta $TMPDIR/$f 2>&1|;
    die "upgrade(): $!" if $?;
    /Wrote:\s+(.*)$/ && ($info{rpm} = $1) && last for reverse @ret;
    inst_rpm(\%info);
    exit;
    }

sub changelog {
    my @dow = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
    my @mon = ("Jan", "Feb", "Mar", "Apr", "May", "Jun"
        , "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        );

    return sprintf("%s %s %d %d %s"
          , $dow[(localtime)[6]]
        , $mon[(localtime)[4]]
        , (localtime)[3]
        , 1900 + (localtime)[5]
        , sprintf("%s\@%s", (getpwuid($<))[0], hostname())
        );
    }

sub trim {
    map { $_ ||= ""; s/^\s+//; s/\s+$//; } @_;
    unless (defined wantarray()) {
        $_ ||= ""; s/^\s+//; s/\s+$//;
        }
    $_[0] if @_ == 1;
    }

# dirty way to untaint stuff to make suExec happy

sub untaint {
    my $k = shift;
    my %x; $x{$k} = 1;
    return (keys %x)[0];
    }

sub debug {
    my $msg = shift;
    my $level = shift || 1;
    $info{debug} ||= 0;
    print "> $msg\n" if $level <= $info{debug};
    }

sub syntax {
    my $args = shift;
    my $warn = shift;

    print "Error:   $warn\n\n" if $warn;

    local $_ = <<EOF;
    This script automates the creation of RPMs from CPAN modules.
    For further information please see the man page.
EOF
    s/^\s+//mg; print;
    print "\nSyntax: cpan2rpm [options] <module>\n\n";
    print "Where <module> is either the name of a Perl module (e.g.\n";
    print "Proc::Daemon) or of a tarball (e.g. Proc-Daemon-0.02.tar.gz),\n";
    print "and [options] is any of the following:\n\n";
    for (sort keys %$args) {
        my ($arg) = split /[:=|]/;
        $arg = "-$arg" if length($arg) > 1;
        $arg = "-$arg" if $arg;
        printf("  %-15s %s\n", $arg, $args->{$_});
        }
    print "\n";
    exit(1);
    }

1;    # yipiness

__END__

=head1 NAME

cpan2rpm - A Perl module packager

=head1 SYNOPSIS

To download the tarball from CPAN and create an RPM package, its source package and the specfile:

    cpan2rpm Proc::Daemon /tmp/String-Canonical-1.2.tar.gz

To install from a URL:

    cpan2rpm -i http://.../Proc-Daemon-0.03.tar.gz

To make a package out of the current directory (that contains a module):

    cpan2rpm .

To create a list of packages stored in a file:

    cpan2rpm -f module-list

=head1 DESCRIPTION

This script generates an RPM package from a Perl module.  It uses the standard RPM file structure and creates a spec file, a source RPM, and a binary, leaving these in their respective directories.

The script can operate on local files, directories, urls and CPAN module names.  Install this package if you want to create RPMs out of Perl modules.

The syntax for cpan2rpm supports multiple I<distribution> names, which can take one of four different forms:

=over

=item 1. B<a CPAN module name> (e.g. XML::Simple) - When a module name is passed, the script will "walk" search.cpan.org to determine the latest distribution.  If an exact match is not found, the CPAN module is used to make this determination.  If you have not yet configured this module, please refer to the REQUIREMENTS section below for further instructions.

=item 2. B<a URL> (both F<http://> and F<ftp://> style locators will work) - In this and the above case, an automatic download of the needed tarball is performed (see notes for how).  The tarball is deposited in the SOURCES directory.

=item 3. B<a path to a tarball> (e.g. F</tmp/XML-Simple-1.05.tar.gz>) - In this case, the tarball indicated gets copied to the SOURCES directory.

=item 4. B<a directory path> - The directory specified must contain a F<Makefile.PL>.  If the user intends to build a package from a directory (i.e. user does NOT specify B<--spec-only>), the commands:

    perl Makefile.PL
    make
    make dist

will be performed in that directory in order to create the tarball necessary for package creation.

=back

=head1 NOTES

At present the script will handle B<.tar.gz>, B<.tgz>, B<.bz2> and B<.zip> tarballs but each of these types requires the appropriate decompression programs installed on the system.

Spec files generated will generally assume header values as configured in the RPM macro files which are evaluated in the following order: F</usr/lib/rpm/macros>, F</etc/rpm/macros> and F<~/.rpmmacros>.  Most of these headers can, however, be overridden through options.  Whenever a header is neither configured in the RPM macro files nor is passed at the command line, the script will seek to calculate a proper value and supplies a default as stated for each option below.  It is thus typically sufficient to provide only the I<distribution> name.

=head1 OPTIONS

The distribution name may be preceded by a number of optional arguments which modify the behaviour of the script.  These options are grouped into three main categories as described below.  Additionally, options may be stored in a configuration file - see the CONFIGURATION FILE section below.

=head2 SPEC Options

The following options control the contents of the specification file generated.  They come in four flavours as follows:

B<Simple Tags>

These represent all tags which get inserted in the package with single values.  The option may be used on the command line only once.

=over

=item B<--name=C<string-value>>

This option corresponds to the I<Name> tag in the spec file.  As is customary with Perl RPMs, the string C<perl-> will be prepended to any value passed here.  If no value is supplied, the script will use the NAME field found in the module's Makefile.PL

=item B<--no-prfx>

Even though this script is meant to build RPM packages from CPAN modules, it may be used on a more generic basis, thus the C<perl-> prefix in a package may be undesirable.  As an example, cpan2rpm generates itself but is not called C<perl-cpan2rpm>.  This option suppresses the aforementioned prefix in the package name.

=item B<--no-depchk>

At times the user may want to package a module that depends on other CPAN modules not presently installed.  This is generally not possible since cpan2rpm does an up-front check for modules listed in the PREREQ_PM field of the F<Makefile.PL>.  This switch turns this checking off so that the process may continue and implies the B<--make-no-test> since testing with missing module dependencies will certainly fail.

=item B<--summary=C<string-value>>

A one-line description of the package.  If left unspecified the script will use the module name, appending an abstract whenever available.

=item B<--version=C<float-value>>

The script determines the version number of the module by consulting the F<Makefile.PL>'s VERSION or VERSION_FROM fields.  If neither is specified, it parses the tarball name.  Note: If you're looking to get the version of cpan2rpm itself, see the I<-V> option.

=item B<--release=C<integer-value>>

The package release number. Defaults to 1. Allows alphanumerics.

=item B<--epoch=C<integer-value>>

By default, this tag is not written to the spec file.  Enter a value here when needed.

=item B<--author=C<string-value>>

This is the name and address of the person who authored the module.  Typically it should be in the format: I<Name <e-mail-addressE<gt>>.  If left unspecified, the script will attempt to extract it from the tarball's MakeMaker file, failing to build the package otherwise.  There is no default for this option.

=item B<--packager=C<string-value>>

This is you (if you're packaging someone else's module).  The string should be in the same format as for --author and defaults to: C<Arix International <cpan2rpm@arix.comE<gt>> unless the RPM macro files provide a value.

=item B<--distribution=C<string-value>>

This key overrides the %{distribution} tag as defined in the macros files.  There is no default for this tag and will be left out unless specified.

=item B<--license=C<string-value>>

The license header specified in the spec file.  This field is also sometimes referred to as I<Copyright>, but I<License> is a more suitable name and has become more common.  Defaults to C<Artistic>, Perl's own license.

=item B<--group=C<string-value>>

This is the RPM group.  For further information on available groups please see your RPM documentation.  Defaults to C<Applications/CPAN>.

=item B<--url=C<string-value>>

The home url for the package.  Defaults to F<http://www.cpan.org>.

=item B<--buildarch=C<string-value>>

The architecture for a package is determined by whether the tarball includes files matching F<*.xs> or F<*.c>.  If it does, I<%_arch> macro from rpm is used as the target architecture, otherwise F<noarch> is used.  This value may be overridden with this parameter.  Typically the package build will be found in the F<RPMS> directory, under the indicated architecture.

=item B<--buildroot=C<string-value>>

Allows specifying a directory to use as a BuildRoot.  Don't mess with this is you don't know what it is.  Defaults to: C<%{_tmppath}/%{name}-%{version}>.

=item B<--defattr=C<-,root,root>>

Upon installation of a package created with cpan2rpm, the files installed are owned according to the contents of the %defattr tag inserted into the %files section of the spec file.  The value of this tag may be passed using this switch and defaults to the value shown above.

=item B<--description=C<string-value>>

This text describes the package/module.  This value is picked up from the POD's Synopsis section in the module.  Defaults to C<None.>.

=back

B<Aggregate Tags>

These represent tags which may be repeated in the spec file.  With all of the following, users may either specify a single option with a comma-delimited string of values, or multiple options, each with a single value.

I<exempli gratia>

  --requires="rpm, rpm-build"
  --requires="rpm" --requires="rpm-build"

=over

=item B<--provides=C<string-value>>

Indicates that a package is provided by the module being built.  RPM will generate an appropriate list of provide dependencies and any passed here will be I<in addition> to those calculated.

=item B<--requires=C<string-value>>

Indicates packages that should be required for installation.  This option works precisely as B<--provides> above.

=item B<--no-requires=C<string-value>>

Suppresses generation of a given required dependency.  Sometimes authors create dependencies on modules the packager can't find, sometimes RPM generates spurious dependencies.  This option allows the packager to arbitrarily supress a given requirement.

=item B<--buildrequires=C<string-value>>

This option indicates dependencies at build time.

=item B<--patch=C<string-value>>

Allows for specifying patch files to be inserted into the spec file and applied when building the source.

=item B<--define=C<name body>>

Works much like the rpm --define syntax to define rpm macro initializations.  A comma-delimited list of macro definitions is not supported, but ut may be used multiple times to define more than one macro.

I<exempli gratia>

  --define="suidperl 1"
  --define "usethreads 1"
  --define admindir=/var/www/html/admin

=item B<--doc=C<string-value>>

This option may be used to add values to the I<%doc> line in the spec's I<%files> section.  By default, cpan2rpm examines the contents of a tarball, using a regular expression to pick up files it recognises as belonging to the F</usr/share/doc> directory.  If your module contains files cpan2rpm does not recognise, they may be added with this option.

Additionally, the user may replace the calculated list by providing values prepended with an equal sign.  In the following example, ONLY the C<Changes> file is added to the list, dismissing any files found by the script:

I<--doc "=Changes">

=back

B<Section options>

These represent tags which may be repeated in the spec file.  Users may specify these either with a single option and a comma-delimited string of values, or by repeating the option, each with a single value.

=over

=item B<--prologue=C<E<lt>sectionE<gt>:E<lt>codeE<gt>>>

This option allows the user to insert arbitrary code at the top of a given section of the spec file.  The section is named in the value passed to the option as the first word followed by a colon.  At present, the following sections are supported: I<prep>, I<build>, I<install>, I<clean>, I<changelog>.

=item B<--epilogue=C<E<lt>sectionE<gt>:E<lt>codeE<gt>>>

As with the previous option, this may be used to insert code at the end of a given section.  This option also supports the I<tag> and I<files> sections which allow for the user to insert extra tags or files to the spec file.

I<exempli gratia>

--epilogue="tag:epoch: 1"

=back

=head2 Building options

The following options control the package making process.

=over

=item B<--spec-only>

This option instructs the script to only generate a spec file and not build the RPM package.

=item B<--spec=path>

This option allows the user to specify the full-path of the spec file to produce.  By default, the specfile is placed in the SPECS directory and is named after the module with a F<.spec> extension.
Please note that cpan2rpm will overwrite existing files, so if you care about your current spec file, save it!

=item B<--make-maker=C<string-value>>

This option allows passing a string to the MakeMaker process (i.e. perl Makefile.PL <your-arguments-here>).  At present there is no support for passing parameters to Module::Build->new() - if this is either possible or desired, please mail the author.

=item B<--make=C<string-value>>

Arguments supplied here get passed directly to the make process.  (As with the above, no support is offered for Module::Build).

=item B<--make-no-test>

Use this option to suppress running a module's test suite during build.

=item B<--make-install=C<string-value>>

Allows user to supply arguments to the make install process.  (As with the above, no support is offered for Module::Build).

=item B<--find-provides=C<string-value>>

=item B<--find-requires=C<string-value>>

These two options allow for redefining the RPM macros of the same name in the spec file.

=item B<--tempdir=C<string-value>>

Specify a temporary working directory instead of utilizing File::Temp.

=item B<--req-scan-all>

By default, the I<rpm-build> requirements script scans all files in a tarball for requirements information.  As this may on occasion generate requirements on the produced rpm that belong only to sample programs or other files not critical to the module being installed, we provide a patch the user may apply (included in this distribution as F<perl.req.patch>) which causes dependencies to be harvested from only F<.pm> files.  When this patch is installed, this switch reverses the behaviour, causing I<cpan2rpm> to scan all files as originally intended.

=item B<--no-clean>

By default, the system passes I<--clean> to F<rpmbuild>, thus removing the unpacked sources from the BUILD directory.  This option suppresses that functionality.

=item B<--shadow-pure>

Forces installation under F<installarchlib> even if the module is pure perl.  This is significant because it is first in the @INC search for module determination.  This will not do any good for modules with XS code or those that are already installed into an architecture dependent path.  This is most useful for those pure perl modules that come stock with the perl rpm itself (i.e. Test::Harness) but you wish to try another version without having to be forced to use "rpm --replacefiles" and destroying the old files.  Using this option will allow both versions of the module to be installed, but the new version will just mask the old version later in the @INC.  Additionally, the new man pages will mask the old man pages even though the man pages for both version will be installed.  This option should only be used as a last resort to install a module when "conflicts" errors occur on rpm installation such as the following: C<file from install of perl-Module-1.11-1 conflicts with file from package perl-5.x.x>
User may be required to use --force (see below) in conjuction with this option to build a fresh rpm before attempting to --install again.

=item B<--force>

By default the script will do as little work as possible i.e. if it has already previously retrieved a module from CPAN, it will not retrieve it again.  If it has already generated a spec file it will not generate it again.  This option allows the packager to force all actions, starting from scratch.

=item B<--no-sign>

Suppresses package signatures.  By default, cpan2rpm will sign the packages it generates IF the the RPM macros file has been configured to use signatures - this option prevents this behaviour.  See also the I<--sign-setup> option below.

=item B<--install | -i>

Install the RPM after building it.  If non-root user, you must have "sudo rpm" privileges to use this option.

=back

=head2 Miscellaneous options

The options below perform functions not closely related to the quotidien process of building a package.

=over

=item B<--fetch=C<string-value>>

One of B<cpanplus>, B<cpan> or B<web>, this parameter specifies which method to use when retrieving a module from CPAN.  Web retrievals are by parsing the CPAN website and may be faster though more error prone.  To use either the CPAN or CPAN+ modules, these must be installed.  Default: web.

=item B<--modules, -f =C<string-value>>

Lists of modules to be processed can be stored in a file.  Pass this parameter the name of your file.  The file should contain the name of each module in a single line and the modules can be specified in any of their many forms (e.g. url, path to tarball, CPAN module name, etc.).  Comments (begining with #) will be ignore and so will empty lines.

=item B<--mk-rpm-dirs=C<string-value>>

This option allows the non-root user to easily set up his account for building packages.  The option requires a directory path where the RPMS, SPECS, etc. subdirectories will be created.  These directories will contain the spec files, binaries and the source packages generated.  Additionally the I<%_topdir> macro will be defined in the F<~/.rpmmacros> file.  If this file doesn't exist it will be created, if it does but does not contain a definition for this macro, it will be appended to it.  Suggested value is F<~/rpm> but it's up to user.

Additionally, the script will create architecture directories F<i386>, F<i686> and F<noarch> and allows the user to pass B<--buildarch> to also create a directory for that architecture.

=item B<--sign-setup=[C<type:user>]>

This option sets up your RPM macros file to support the signing of packages.  The option may be passed a value consisting of the signature type to use (currently only B<gpg> and B<pgp> are valid but consult the RPM man pages), a colon, and the user name to sign with.  If no value is passed C<gpg> is used for the signature type and the first key listed in the secure keyring is taken for signing.

B<Note:> unless you know what you're doing, do not pass any arguments to this option!  Also,  make sure not to pass a module name as an argument.

To further tailor your macros file please refer to the I<GPG SIGNATURES> section of the RPM man page.

=item B<--upgrade>

Whenever a new version of this program becomes available, an automatic notification will be issued to the user of this fact.  The user may then choose to upgrade via this option.  The option takes no parameters.

=item B<--no-upgrade-chk|-U>

During version checks, the script will time out within 5 seconds if the F<arix.com> server is unavailable (when working offline or if the server is down).  Should the 5 seconds become annoying, users may pass this option to skip the version check.

=item B<--debug[=n]>

This option produces debugging output.  An optional integer increases the level of verbosity for this output.  If no integer is given, 1 is assumed.

=item B<--help, -h>

Displays a terse syntax message.

=item B<-V>

This option displays the version number of cpan2rpm itself.

=item B<-D>

This option runs cpan2rpm in the Perl debugger.  Useful for anyone willing to dig on my behalf.

=back

=head1 CONFIGURATION FILE

In addition to reading options from the command line, cpan2rpm will slurp the configuration file F<~/.cpan2rpm>, if it exists.  Please note that for this functionality to work, the module F<Getopt::ArgvFile> must be installed.  If the config file exists but the module is not available, cpan2rpm will puke.

Additionally, please note that if no config file exists in the $HOME directory, one may be passed explicitly on the command line as shown in the example below:

    # cpan2rpm @options-file -V

Note that options from command line will override options from config file.

The configuration file should contain options in same format as they would be used in command line.  Place one option per line.

Example:

    --packager="John Doe <john.doe@example.com>"
    --url="http://example.com/johndoe/perlmodules/"

=head1 REQUIREMENTS

This script requires that RPM be installed.  Both the B<rpm> and B<rpm-build>
packages must be installed on the local machine.  Please see the RPM documentation (man rpm) for further information.

Additionally, the B<Perl> package will be needed :) and the CPAN module
(which is bundled with the Perl distribution) will need to be configured.  To configure CPAN (CPAN.pm or CPAN/MyConfig.pm) use the following:

    perl -MCPAN -e shell

For further information please refer to the CPAN manpage.

=head1 SUPPORTED PLATFORMS

At present, B<cpan2rpm> has been tested and is known to work under the following environments:

=over

=item B<Operating Systems>

The script has been tested under the OS list below:

    - Linux RedHat: 6.1, 6.2, 7.0, 7.2, 7.3, 8.0, 9.0
    - Linux Enterprise v3 (RHELv3)
    - SuSE 8.1, 9.0

Rumour has it it's been tested on Solaris and FreeBSD as well but I don't know for sure.  See README.redhat6 for 6.x issues to be aware of.

=item B<Perl>

The script is known to work with Perl versions 5.005_03, 5.6.0, 5.6.1 and 5.8.0.

=item B<ExtUtils::MakeMaker>

This module is used for making and installing the CPAN modules.  However many of MakeMaker's versions are broken and incompatible with other versions.  For that reason, B<cpan2rpm> works well with versions < 5.91 and > 6.05 but in between it requires an upgrade.

=item B<Module::Build>

This module replaces the old and crusty MakeMaker.  At present not all modules yet use this new install method so cpan2rpm autodetects the install method and supports both.  Please note that some of the meta-data retrieval functions may not work as well with this module as it requires less information to be present in the initial script than does MakeMaker.

=item B<Redhat Package Manager>

The RPM system has undergone a lot of change.  At present, B<cpan2rpm> runs on version 4.0.4-7x but requires certain special attention (see README for more information).  Earlier versions of RPM are borked in various ways and are not currently supported, though on SuSE version 3.0.6 appears to work.

=back

If you are running on a platform not listed above, do drop us a note and let us know!

=head1 AUTHOR

Erick Calder <ecalder@cpan.org>

=head1 ACKNOWLEDGEMENTS

The script was inspired by B<cpanflute> which is distributed with the rpm-build package from RedHat.  Many thanks to Robert Brown <bbb@cpan.org> for all his cool tricks, advice and patient support.

=head1 SUPPORT/BUGS

Thank you notes can be mailed directly to the author :)

For help, you can subscribe to our mailing list at:

F<http://lists.sourceforge.net/lists/listinfo/cpan2rpm-general>

or send a message to F<cpan2rpm-general-request@lists.sourceforge.net> with C<help> as the subject header.  Please note, when submitting patches, please first retrieve the latest (unreleased version of the script from the home page).

Feature requests, bug reports and patch submissions should also be handled through SourceForge.

=head1 TODO

Some things we're working on/thinking about:

1. extract all functionality into a perl module and make cpan2rpm a thin script
2. allow macro definitions like C<%_sourcedir %_topdir/%name> in F<.rpmmacros> file (%name isn't defined till later)
3. a --recursive option to install perl rpm dependencies
4. Provides: requirements are generated in the form "perl(POE::Filter) = 1.12" but not "perl-POE-Filter = 1.12" which is for SuSE.
5. PREREQ_PM should be added to the unique list of requirements for the RPM
6. look into --make-test-continue to move past failed testing
7. rethink --force

=head1 AVAILABILITY

The latest version of the tarball, RPM and SRPM may always be found at:

F<http://perl.arix.com/>

Additionally, the module is available on CPAN at:

F<http://search.cpan.org/author/ECALDER/cpan2rpm/>

and the project is also hosted on SourceForge at:

F<http://sourceforge.net/projects/cpan2rpm/>

=head1 CHANGES

The distribution includes a F<Changes> file which details the evolution of
this utility.  For your convenience, this file may also be found online at:

F<http://perl.arix.com/cpan2rpm/Changes>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2002-2003 Erick Calder <ecalder@cpan.org>

This product is free and distributed under the Gnu Public License (GPL).  A copy of this license was included in this distribution in a file called LICENSE.  If for some reason, this file was not included, please see F<http://www.gnu.org/licenses/> to obtain a copy of this license.

$Id: cpan2rpm,v 2.294 2005/02/07 17:25:27 ekkis Exp $

=cut

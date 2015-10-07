#!/usr/bin/env perl 

# specify minimum version of perl
use 5.010;

use strict;
use warnings;
use File::Path qw(mkpath);
use File::Copy;
use File::Spec;
use File::Basename;
use Data::Dumper;
use Cwd qw(abs_path);
use POSIX qw(strftime);
use Getopt::Long;
use English;
no if ($PERL_VERSION ge v5.18.0), 'warnings' => 'experimental::smartmatch';

#-----------------------------------------------------------------------------------------------
# Global data. 
#-----------------------------------------------------------------------------------------------

my $CASEROOT; 
my $CASEBUILD;
my $CASETOOLS;
my $CIMEROOT;
my $LIBROOT;
my $INCROOT; 
my $SHAREDLIBROOT;
my $COMPILER; 
my $CASE; 
my $EXEROOT;
my $BUILD_THREADED;
my $MODEL;
my $COMP_ATM;
my $COMP_LND;
my $COMP_ICE;
my $COMP_OCN;
my $COMP_GLC;
my $COMP_WAV;
my $COMP_ROF;
my $COMP_INTERFACE;
my $CONFIG_ATM_DIR;
my $CONFIG_LND_DIR;
my $CONFIG_ICE_DIR;
my $CONFIG_OCN_DIR;
my $CONFIG_GLC_DIR;
my $CONFIG_WAV_DIR;
my $CONFIG_ROF_DIR;
my $DEBUG;
my $USE_ESMF_LIB;
my $MPILIB;
my $SMP_VALUE;
my $NINST_BUILD;
my $CISM_USE_TRILINOS;
my $SHAREDPATH;
my $CLM_CONFIG_OPTS;
my $CAM_CONFIG_OPTS;
my $sysmod;
my $machines_dir;

# Stash the build log paths here..
my @bldlogs;

my $LID = strftime("%y%m%d-%H%M%S", localtime);
my $banner = "-------------------------------------------------------------------------\n";
my $logger;
#-----------------------------------------------------------------------------------------------
 
my %opts = (loglevel => "INFO");
GetOptions("loglevel=s" => \$opts{loglevel});

sub main {

    $CASEROOT = abs_path(".");
    print "CASEROOT: $CASEROOT\n";
    chdir "$CASEROOT" or die "Could not cd to $CASEROOT: $!\n";

    $CIMEROOT = `./xmlquery  CIMEROOT		-value `;

    if(! -d "$CIMEROOT"){
	die("Could not find cimeroot in \"$CIMEROOT\""); 
    }
    my @dirs = ("$CIMEROOT/utils/perl5lib");
    unshift @INC, @dirs;
    require Log::Log4perl;
    require Module::ModuleLoader;
    require Config::SetupTools;

    my $level = Log::Log4perl::Level::to_priority($opts{loglevel});
    Log::Log4perl->easy_init({level=>$level,
			      layout=>'%m%n'});


    $logger = Log::Log4perl::get_logger();
    my %xmlvars = SetupTools::getAllResolved();

    $CASE = $xmlvars{CASE};
    if (! -f "$CASE.run") {
	$logger->logdie ("ERROR: must invoke case_setup script before calling build script ");
    }

    $sysmod = "./Tools/check_lockedfiles -cimeroot $CIMEROOT";
    system($sysmod) == 0 or $logger->logdie ("$sysmod failed: $?");

    $BUILD_THREADED	= $xmlvars{ BUILD_THREADED};
    $CASEBUILD	        = $xmlvars{ CASEBUILD};
    $CASETOOLS          = $xmlvars{ CASETOOLS};
    $EXEROOT	        = $xmlvars{ EXEROOT	};
    $INCROOT		= $xmlvars{ INCROOT	};
    $LIBROOT		= $xmlvars{ LIBROOT	};
    $SHAREDLIBROOT	= $xmlvars{ SHAREDLIBROOT};
    $COMP_ATM		= $xmlvars{ COMP_ATM	};
    $COMP_LND		= $xmlvars{ COMP_LND	};
    $COMP_ICE		= $xmlvars{ COMP_ICE	};
    $COMP_OCN		= $xmlvars{ COMP_OCN	};
    $COMP_GLC		= $xmlvars{ COMP_GLC	};
    $COMP_WAV		= $xmlvars{ COMP_WAV	};
    $COMP_ROF		= $xmlvars{ COMP_ROF	};
    $COMPILER		= $xmlvars{ COMPILER	};
    $COMP_INTERFACE	= $xmlvars{ COMP_INTERFACE};
    $MPILIB		= $xmlvars{ MPILIB	};
    $USE_ESMF_LIB	= $xmlvars{ USE_ESMF_LIB};
    $DEBUG		= $xmlvars{ DEBUG	};
    $NINST_BUILD        = $xmlvars{ NINST_BUILD};
    $SMP_VALUE          = $xmlvars{ SMP_VALUE};
    $MODEL              = $xmlvars{ MODEL};
    my $NINST_VALUE	= $xmlvars{ NINST_VALUE};
    my $MACH		= $xmlvars{ MACH	};
    my $OS	        = $xmlvars{ OS	};
    my $COMP_CPL	= $xmlvars{ COMP_CPL	};
    my $machines_file   = $xmlvars{ MACHINES_SPEC_FILE};
    $machines_dir       = dirname($machines_file);

    my $CONFIG_ATM_FILE	= $xmlvars{ CONFIG_ATM_FILE};
    my $CONFIG_LND_FILE	= $xmlvars{ CONFIG_LND_FILE};
    my $CONFIG_ICE_FILE	= $xmlvars{ CONFIG_ICE_FILE};
    my $CONFIG_OCN_FILE	= $xmlvars{ CONFIG_OCN_FILE};
    my $CONFIG_GLC_FILE	= $xmlvars{ CONFIG_GLC_FILE};
    my $CONFIG_WAV_FILE	= $xmlvars{ CONFIG_WAV_FILE};
    my $CONFIG_ROF_FILE	= $xmlvars{ CONFIG_ROF_FILE};
    $CONFIG_ATM_DIR	= dirname($CONFIG_ATM_FILE);
    $CONFIG_LND_DIR	= dirname($CONFIG_LND_FILE);
    $CONFIG_ICE_DIR	= dirname($CONFIG_ICE_FILE);
    $CONFIG_OCN_DIR	= dirname($CONFIG_OCN_FILE);
    $CONFIG_GLC_DIR	= dirname($CONFIG_GLC_FILE);
    $CONFIG_WAV_DIR	= dirname($CONFIG_WAV_FILE);
    $CONFIG_ROF_DIR	= dirname($CONFIG_ROF_FILE);

    $ENV{CIMEROOT}		= $CIMEROOT		;
    $ENV{CASETOOLS}		= $CASETOOLS		;
    $ENV{EXEROOT}		= $EXEROOT		;
    $ENV{INCROOT}		= $INCROOT		;
    $ENV{LIBROOT}		= $LIBROOT		;
    $ENV{SHAREDLIBROOT}		= $SHAREDLIBROOT	;
    $ENV{CASEROOT}		= $CASEROOT		;
    $ENV{COMPILER}		= $COMPILER		;
    $ENV{COMP_INTERFACE}	= $COMP_INTERFACE	;
    $ENV{NINST_VALUE}		= $NINST_VALUE	        ;
    $ENV{BUILD_THREADED}	= $BUILD_THREADED	;
    $ENV{MACH}			= $MACH			;
    $ENV{USE_ESMF_LIB}		= $USE_ESMF_LIB		;
    $ENV{MPILIB}		= $MPILIB		;	
    $ENV{DEBUG}			= $DEBUG		;	
    $ENV{OS}			= $OS			;
    $ENV{COMP_CPL}		= $COMP_CPL		;	
    $ENV{COMP_ATM}		= $COMP_ATM		;	
    $ENV{COMP_LND}		= $COMP_LND		;	
    $ENV{COMP_ICE}		= $COMP_ICE		;	
    $ENV{COMP_OCN}		= $COMP_OCN		;	
    $ENV{COMP_GLC}		= $COMP_GLC		;	
    $ENV{COMP_WAV}		= $COMP_WAV		;	
    $ENV{COMP_ROF}		= $COMP_ROF		;	
    
    $ENV{OCN_SUBMODEL}        = $xmlvars{ OCN_SUBMODEL};
    $ENV{PROFILE_PAPI_ENABLE} = $xmlvars{ PROFILE_PAPI_ENABLE};
    $ENV{LID}  =  "`date +%y%m%d-%H%M%S`";

    if ($COMP_ATM eq 'cam') {
	$CAM_CONFIG_OPTS = $xmlvars{ CAM_CONFIG_OPTS};
	$ENV{CAM_CONFIG_OPTS} = $CAM_CONFIG_OPTS      ;
    }
    if ($COMP_LND eq 'clm') {
	$CLM_CONFIG_OPTS = $xmlvars{ CLM_CONFIG_OPTS};
	$ENV{CLM_CONFIG_OPTS} = $CLM_CONFIG_OPTS      ;
    }

    # Set the overall USE_TRILINOS variable to TRUE if any of the 
    # XXX_USE_TRILINOS variables are TRUE. 
    # For now, there is just the one CISM_USE_TRILINOS variable, but in
    # the future there may be others -- so USE_TRILINOS will be true if
    # ANY of those are true.
    $CISM_USE_TRILINOS = $xmlvars{CISM_USE_TRILINOS};
    my $use_trilinos = 'FALSE';
    if ($CISM_USE_TRILINOS) {
	if ($CISM_USE_TRILINOS eq 'TRUE') {$use_trilinos = 'TRUE'};
	my $sysmod = "./xmlchange USE_TRILINOS=${use_trilinos}";
	$ENV{USE_TRILINOS} = ${use_trilinos};
	$ENV{CISM_USE_TRILINOS} = $CISM_USE_TRILINOS;
    }

    my $moduleloader = Module::ModuleLoader->new(machine   => $MACH, 
						 compiler  => $COMPILER, 
						 mpilib	   => $MPILIB, 
						 debug	   => $DEBUG, 
						 caseroot  => $CASEROOT, 
						 cimeroot  => $CIMEROOT, 
						 model	   => $MODEL);
    $moduleloader->moduleInit();
    $moduleloader->findModulesForCase();
    $moduleloader->loadModules();

    $logger->info("    .... checking namelists (calling ./preview_namelists) ");
    $sysmod = "./preview_namelists -loglevel $opts{loglevel}";
    system($sysmod) == 0 or $logger->logdie ("$sysmod failed: $?");
    
    checkInputData(\%xmlvars);
    buildChecks(\%xmlvars);
    buildLibraries(\%xmlvars);
    buildModel(\%xmlvars);
}


#-----------------------------------------------------------------------------------------------
sub checkInputData()
{
    my($xmlvars) = @_;
    $logger->info( "    .... calling data prestaging  ");

    chdir "$CASEROOT" or $logger->logdie( "Could not cd to $CASEROOT: $!");

    my $DIN_LOC_ROOT	= $xmlvars->{DIN_LOC_ROOT	};
    my $GET_REFCASE	= $xmlvars->{GET_REFCASE	};
    my $RUN_TYPE	= $xmlvars->{RUN_TYPE		};
    my $RUN_REFDATE	= $xmlvars->{RUN_REFDATE	};
    my $RUN_REFCASE	= $xmlvars->{RUN_REFCASE	};
    my $RUN_REFDIR	= $xmlvars->{RUN_REFDIR	};
    my $RUNDIR		= $xmlvars->{RUNDIR		};
    my $CONTINUE_RUN	= $xmlvars->{CONTINUE_RUN	}; 

    my @inputdatacheck = qx(./check_input_data -inputdata $DIN_LOC_ROOT -check);

    my @unknown = grep { /unknown/ } @inputdatacheck;
    if (@unknown) {
	$logger->warn ("      Any files with \"status uknown\" below were not found in the expected 
	       location, and are not from the input data repository. This is for 
	       informational only; this script will not attempt to find thse files. 
	       If these files are found or are not needed no error will result.\n".map {print "$_\n" } @unknown);
    }
	
    my @missing = grep { /missing/ } @inputdatacheck;
    if (@missing) {
	$logger->info("Attempting to download missing data");
	qx(./check_input_data -inputdata $DIN_LOC_ROOT -export);

	$logger->info("Now checking if required input data is in $DIN_LOC_ROOT ");

	@inputdatacheck = qx(./check_input_data -inputdata $DIN_LOC_ROOT -check);
	@missing = grep { /missing/ } @inputdatacheck;
	if (@missing) {
	    $logger->logdie( "The following files were not found, they are required".
			     map {print "$_\n" } @missing ."\n".
			     "Invoke the following command to obtain them:
                	    ./check_input_data -inputdata $DIN_LOC_ROOT -export");
	}
    }
	
    if( ($GET_REFCASE eq 'TRUE') && ($RUN_TYPE ne 'startup') && ($CONTINUE_RUN eq 'FALSE') )  {
	my $refdir = "${RUN_REFDIR}/${RUN_REFCASE}/${RUN_REFDATE}";
	if (! -d "${DIN_LOC_ROOT}/${refdir}") {
	    $logger->logdie(
	     "***************************************************************** 
	    ccsm_prestage ERROR: $refdir is not on local disk 
	    obtain this data from the svn input data repository 
	    > mkdir -p $refdir 
	    > cd $refdir 
	    > cd ..
	    > svn export --force https://svn-ccsm-inputdata.cgd.ucar.edu/trunk/inputdata/${refdir} 
	     or set GET_REFCASE to FALSE in env_run.xml 
	    and prestage the restart data to $RUNDIR manually 
            *****************************************************************" );

     	} else {

	    $logger->info( " - Prestaging REFCASE ($refdir) to $RUNDIR");
		
	    # prestage the reference case's files.
	    mkpath ($RUNDIR) if (! -d $RUNDIR);
		
	    my @refcasefiles = glob("${DIN_LOC_ROOT}/${refdir}/*${RUN_REFCASE}*");
	    foreach my $rcfile (@refcasefiles) {

		my $rcbaseline = basename($rcfile);
		if(! -f "${RUNDIR}/$rcbaseline") {
		    my $sysmod = "ln -s $rcfile $RUNDIR/.";
		    system($sysmod) == 0 or $logger->warn ("$sysmod failed: $?");
		}
			
		# copy the refcases' rpointer files to the run directory
		my @rpointerfiles = glob("${DIN_LOC_ROOT}/$refdir/*rpointer*");
		foreach my $rpointerfile(@rpointerfiles) {
		    copy($rpointerfile, ${RUNDIR});
		}
		chdir "$RUNDIR" or $logger->logdie ("Could not cd to $RUNDIR: $!");

		my @cam2_list = glob("*.cam2.*");
		foreach my $cam2file(@cam2_list) {
		    my $camfile = $cam2file;
		    $camfile =~ s/cam2/cam/g;
		    symlink($cam2file, $camfile);
		}
	
		my @allrundirfiles = glob("$RUNDIR/*");
		foreach my $runfile(@allrundirfiles) {
		    chmod 0755, $runfile;
		}
	    }
	}
    }
}


#-----------------------------------------------------------------------------------------------
sub buildChecks()
{
    my($xmlvars) = @_;
    $logger->info("    .... calling build checks ");
	
    chdir "$CASEROOT" or $logger->logdie("Could not cd to $CASEROOT: $!");
	
    my $NTHRDS_CPL   = $xmlvars->{ NTHRDS_CPL	};
    my $NTHRDS_ATM   = $xmlvars->{ NTHRDS_ATM	};
    my $NTHRDS_LND   = $xmlvars->{ NTHRDS_LND	};
    my $NTHRDS_ICE   = $xmlvars->{ NTHRDS_ICE	};
    my $NTHRDS_OCN   = $xmlvars->{ NTHRDS_OCN	};
    my $NTHRDS_GLC   = $xmlvars->{ NTHRDS_GLC	};
    my $NTHRDS_WAV   = $xmlvars->{ NTHRDS_WAV	};
    my $NTHRDS_ROF   = $xmlvars->{ NTHRDS_ROF	};
    my $NINST_ATM    = $xmlvars->{ NINST_ATM	};
    my $NINST_LND    = $xmlvars->{ NINST_LND	};
    my $NINST_ICE    = $xmlvars->{ NINST_ICE	};
    my $NINST_OCN    = $xmlvars->{ NINST_OCN	};
    my $NINST_GLC    = $xmlvars->{ NINST_GLC	};
    my $NINST_WAV    = $xmlvars->{ NINST_WAV	};
    my $NINST_ROF    = $xmlvars->{ NINST_ROF	};
    my $NINST_VALUE  = $xmlvars->{ NINST_VALUE	};
    my $SMP_BUILD    = $xmlvars->{ SMP_BUILD	};
    my $BUILD_STATUS = $xmlvars->{ BUILD_STATUS};

    my $atmstr = 0;
    my $lndstr = 0;
    my $icestr = 0;
    my $ocnstr = 0;
    my $rofstr = 0;
    my $glcstr = 0;
    my $wavstr = 0;
    my $cplstr = 0;

    if ($NTHRDS_ATM > 1 || $BUILD_THREADED eq 'TRUE') {$atmstr = 1;}
    if ($NTHRDS_LND > 1 || $BUILD_THREADED eq 'TRUE') {$lndstr = 1;}
    if ($NTHRDS_OCN > 1 || $BUILD_THREADED eq 'TRUE') {$ocnstr = 1;}
    if ($NTHRDS_ROF > 1 || $BUILD_THREADED eq 'TRUE') {$rofstr = 1;}
    if ($NTHRDS_GLC > 1 || $BUILD_THREADED eq 'TRUE') {$glcstr = 1;}
    if ($NTHRDS_WAV > 1 || $BUILD_THREADED eq 'TRUE') {$wavstr = 1;}
    if ($NTHRDS_CPL > 1 || $BUILD_THREADED eq 'TRUE') {$cplstr = 1;}
	
    $ENV{'SMP'} = 'FALSE';
    if( $NTHRDS_ATM > 1 || $NTHRDS_CPL > 1 || $NTHRDS_ICE > 1 ||
	$NTHRDS_LND > 1 || $NTHRDS_OCN > 1 || $NTHRDS_GLC > 1 || $NTHRDS_WAV > 1) { $ENV{'SMP'} = 'TRUE';}

    my $smpstr = "a$atmstr"."l$lndstr"."r$rofstr"."i$icestr"."o$ocnstr". "g$glcstr"."w$wavstr"."c$cplstr";

    $sysmod = "./xmlchange SMP_VALUE=$smpstr";
    system($sysmod) == 0 or $logger->logdie( "$sysmod failed: $?");

    $ENV{'SMP_VALUE'} = $smpstr;
	
    my $inststr = "a$NINST_ATM"."l$NINST_LND"."r$NINST_ROF"."i$NINST_ICE"."o$NINST_OCN"."g$NINST_GLC"."w$NINST_WAV";

    $sysmod = "./xmlchange NINST_VALUE=$inststr";
    system($sysmod) == 0 or $logger->logdie( "$sysmod failed: $?");

    $ENV{'NINST_VALUE'} = $inststr;
	
    # set the overall USE_TRILINOS variable to TRUE if any of the XXX_USE_TRILINOS variables are TRUE. 
    # For now, there is just the one CISM_USE_TRILINOS variable, but in the future, there may be others, 
    # so USE_TRILINOS should be  true if ANY of those are true.

    $ENV{'use_trilinos'} = 'FALSE';
    if ($CISM_USE_TRILINOS) {
	if ($CISM_USE_TRILINOS eq 'TRUE') {
	    $ENV{'use_trilinos'} = "TRUE";
	}
    }

    $sysmod = "./xmlchange USE_TRILINOS=$ENV{'use_trilinos'}";
    system($sysmod) == 0 or $logger->logdie( "$sysmod failed: $?");
	
    if( ($NINST_BUILD ne $NINST_VALUE) && ($NINST_BUILD != 0)) {
	my $msg = " ERROR, NINST VALUES HAVE CHANGED \n";
	$msg .= " NINST_BUILD = $NINST_BUILD \n";
	$msg .= " NINST_VALUE = $NINST_VALUE \n";
	$msg .= " A manual clean of your obj directories is strongly recommended \n";
	$msg .= " You should execute the following: \n";
	$msg .= " ./$CASE.clean_build \n";
	$msg .= " Then rerun the build script interactively \n";
	$msg .= " ---- OR ---- \n";
	$msg .= " You can override this error message at your own risk by executing:  \n";
	$msg .= "./xmlchange NINST_BUILD=0 \n";
	$msg .= " Then rerun the build script interactively \n";
	$logger->logdie($msg);
    }

    if ($SMP_BUILD ne $SMP_VALUE && $SMP_BUILD != 0) {
	my $msg = "  ERROR SMP STATUS HAS CHANGED \n";
	$msg .= "  SMP_BUILD = $SMP_BUILD \n";
	$msg .= "  SMP_VALUE = $SMP_VALUE \n";
	$msg .= "  A manual clean of your obj directories is strongly recommended\n";
	$msg .= "  You should execute the following: \n";
	$msg .= "    ./$CASE.clean_build\n";
	$msg .= "  Then rerun the build script interactively\n";
	$msg .= "  ---- OR ----\n";
	$msg .= "  You can override this error message at your own risk by executing\n";
	$msg .= "    ./xmlchange SMP_BUILD=0\n";
	$msg .= "  Then rerun the build script interactively\n";
	$logger->logdie($msg);
    }

    if($BUILD_STATUS != 0) {
	my $msg = "  ERROR env_build HAS CHANGED \n";
	$msg .= "  A manual clean of your obj directories is strongly recommended \n";
	$msg .= "  You should execute the following:  \n";
	$msg .= "      ./$CASE.clean_build \n";
	$msg .= "  Then rerun the build script interactively \n";
	$msg .= "    ---- OR ---- \n";
	$msg .= "  You can override this error message at your own risk by executing  \n";
	$msg .= "      rm LockedFiles/env_build* \n";
	$msg .= "  Then rerun the build script interactively  \n";
	$logger->logdie($msg);
    }

    if ($COMP_INTERFACE eq 'ESMF' && $USE_ESMF_LIB ne 'TRUE') {
	my $msg = " ERROR COMP_INTERFACE IS ESMF BUT USE_ESMF_LIB IS NOT TRUE \n";
	$msg .= " SET USE_ESMF_LIB to TRUE with  \n";
	$msg .= "     ./xmlchange USE_ESMF_LIB=TRUE \n";
	$logger->logdie($msg);

    }
	
    if($MPILIB eq 'mpi-serial' && $USE_ESMF_LIB eq 'TRUE') {
	my $msg = "  ERROR MPILIB is mpi-serial and USE_ESMF_LIB IS TRUE \n";
	$msg .= "    MPILIB can only be used with an ESMF library built with mpiuni on \n";
	$msg .= "  Set USE_ESMF_LIB to FALSE with  \n";
	$msg .= "    ./xmlchange USE_ESMF_LIB=FALSE \n";
	$msg .= "  ---- OR ---- \n";
	$msg .= "  Make sure the ESMF_LIBDIR used was built with mpi-serial (or change it to one that was) \n";
	$msg .= "  And comment out this if block in Tools/models_buildexe \n";
	$logger->logdie($msg);

    }

    $sysmod = "./xmlchange BUILD_COMPLETE=FALSE";
    system($sysmod) == 0 or $logger->logdie ("$sysmod failed: $?");

    my @lockedfiles = glob("LockedFiles/env_build*");
    foreach my $lf (@lockedfiles) {
	unlink($lf);
    }
}


#-----------------------------------------------------------------------------------------------
sub buildLibraries()
{
    my($xmlvars) = @_;
    $logger->info("    .... calling builds for utility libraries (compiler is $COMPILER) ");

    chdir $EXEROOT;

    if ($MPILIB eq 'mpi-serial') {
	my $sysmod = "cp -p -f $CIMEROOT/externals/mct/mpi-serial/\*.h  $LIBROOT/include/.";
	system($sysmod) == 0 or $logger->logdie("$sysmod failed: $?");
    }
    
    my $debugdir = "nodebug";
    if ($DEBUG eq 'TRUE') {$debugdir = "debug";}
    
    my $threaddir = 'nothreads';
    if ($ENV{'SMP'} eq 'TRUE' or $ENV{BUILD_THREADED} eq 'TRUE')
    {
	$threaddir = 'threads';
    }
    
    $ENV{'SHAREDPATH'}  = "$SHAREDLIBROOT/$COMPILER/$MPILIB/$debugdir/$threaddir";
    $SHAREDPATH = $ENV{'SHAREDPATH'};
    if(! -e $SHAREDPATH){ mkpath $SHAREDPATH;}
    mkpath("$SHAREDPATH/lib"    ) if (! -d "$SHAREDPATH/lib"    );
    mkpath("$SHAREDPATH/include") if (! -d "$SHAREDPATH/include");

    my @libs = qw/mct gptl pio csm_share/;
    $logger->info("      build libraries: @libs");

    foreach my $lib(@libs) {
	
	mkpath("$SHAREDPATH/$lib") if (! -d "$SHAREDPATH/$lib");
	chdir "$SHAREDPATH/$lib" or $logger->logdie ("Could not cd to $SHAREDPATH/$lib: $!");

	my $file_build = "$SHAREDPATH/$lib.bldlog.$LID";
	my $now = localtime;
	$logger->info( "      $now $file_build");

# Possibly useful for debug but should not be used by default
#	open my $FB, ">", $file_build or $logger->logdie ($!);
#	map { print $FB "$_: $ENV{$_}\n"} sort keys %ENV;
#	close $FB;
	
	my $file = "${machines_dir}/buildlib.${lib}";
	eval {system("$file $SHAREDPATH $CASEROOT >> $file_build 2>&1")};
	if ($?)	{
	    $logger->logdie("ERROR: buildlib.$lib failed, cat $file_build");
	}
	# push the file_build path into the bldlogs array..
	push(@bldlogs, $file_build);
    }
}


#-----------------------------------------------------------------------------------------------
sub buildModel()
{
    my($xmlvars) = @_;
    $logger->info( "    .... calling builds for component libraries  ");

    chdir "$CASEROOT" or $logger->logdie ("Could not cd to $CASEROOT: $!");

    my $LOGDIR          = $xmlvars->{LOGDIR};

    my @modelsbuildorder = qw( atm lnd ice ocn glc wav rof );
    my %models = ( atm => $COMP_ATM, lnd => $COMP_LND, ice => $COMP_ICE,
                   ocn => $COMP_OCN, glc => $COMP_GLC, wav => $COMP_WAV,
		   rof => $COMP_ROF);
    my %dirs   = ( atm => $CONFIG_ATM_DIR, lnd => $CONFIG_LND_DIR, ice => $CONFIG_ICE_DIR,
		   ocn => $CONFIG_OCN_DIR, glc => $CONFIG_GLC_DIR, wav => $CONFIG_WAV_DIR,
		   rof => $CONFIG_ROF_DIR);
    my $model;

    foreach $model(@modelsbuildorder) {

	my $comp = $models{$model};
	my $compspec = "";
	my $objdir = "";
	my $libdir = ""; 
	my $bldroot = "";

	if ("$comp" eq "clm") {

	    my $ESMFDIR;
	    if ($USE_ESMF_LIB eq "TRUE") {
		$ESMFDIR = "esmf";
	    } else {
		$ESMFDIR = "noesmf";
            }
	    for ("$CLM_CONFIG_OPTS") {
		when (/.*clm4_0.*/) {
		    $logger->info( "         - Building clm4_0 Library ");
		    $objdir = "$EXEROOT/$model/obj" ; if (! -d "$objdir") {mkpath "$objdir"};
		    $libdir = "$EXEROOT/$model"     ; if (! -d "$libdir") {mkpath "$libdir"};
		    $compspec = "lnd";
		    $logger->debug( "       bldroot is $EXEROOT ");
		    $logger->debug( "       objdir  is $objdir ");
		    $logger->debug( "       libdir  is $libdir ");
		} default {
		    $logger->info( "         - Building clm4_5/clm5_0 shared library ");
		    $bldroot = "$SHAREDPATH/$COMP_INTERFACE/$ESMFDIR/" ;
		    $objdir  = "$bldroot/$comp/obj" ; if (! -d "$objdir") {mkpath "$objdir"};
		    $libdir  = "$bldroot/lib"       ; if (! -d "$libdir") {mkpath "$libdir"};
		    $compspec = "clm";
		    $logger->debug( "       bldroot is $bldroot ");
		    $logger->debug ("       objdir  is $objdir ");
		    $logger->debug("       libdir  is $libdir");
		}
	    }

	}  else {

	    $objdir = "$EXEROOT/$model/obj" ; if (! -d "$objdir") {mkpath -p "$objdir";}
	    $libdir = "$EXEROOT/$model"     ; if (! -d "$libdir") {mkpath -p "$libdir";}
	    $compspec = $comp;
	}

	$ENV{'MODEL'} = $model;
	my $file_build = "$EXEROOT/${model}.bldlog.$LID";
	my $now = localtime;
	$logger->info("      .... calling $dirs{$model}/buildlib ");
        $logger->info( "           $now $file_build");

	# build the component library
	chdir "$EXEROOT/$model" or $logger->logdie ("Could not cd to $EXEROOT/$model: $!");

	eval{ system("$dirs{$model}/buildlib $CASEROOT $bldroot $compspec >> $file_build 2>&1") };
	if($?) { $logger->logdie ("ERROR: $comp.buildlib failed, see $file_build");	}

	#push the file_build path into the bldlogs array..
	push (@bldlogs, $file_build);
		
	#--- copy .mod files... 
	my @lcmods = glob("$objdir/*_comp_*.mod");
	my @ucmods = glob("$objdir/*_COMP_*.mod");
	foreach my $mod (@lcmods, @ucmods) {
	    copy($mod, $INCROOT);
	}
    }

    my $file_build = "${EXEROOT}/${MODEL}.bldlog.$LID";
    my $now = localtime;
    $logger->info( "      $now $file_build");

    mkpath "${EXEROOT}/${MODEL}/obj" if (! -d "${EXEROOT}/${MODEL}/obj");
    mkpath "${EXEROOT}/${MODEL}"     if (! -d "${EXEROOT}/${MODEL}");

    # create the model executable 
    chdir "${EXEROOT}/${MODEL}" or $logger->logdie ("Could not cd to ${EXEROOT}/${MODEL}: $!");
    eval{ system("$CIMEROOT/driver_cpl/cime_config/buildexe $CASEROOT >> $file_build 2>&1") };
    if ($?) {$logger->logdie ("ERROR: buildexe failed, cat $file_build");}

    push(@bldlogs, $file_build);
	
    #--- Copy the just-built ${MODEL}.exe to ${MODEL}.exe.$LID
    copy("${EXEROOT}/${MODEL}.exe", "${EXEROOT}/${MODEL}.exe.$LID");
    chmod 0755, "${EXEROOT}/${MODEL}.exe.$LID" or $logger->warn ("could not change perms on ${EXEROOT}/${MODEL}.exe.$LID, $?");
	
    #copy build logs to CASEROOT/logs
    if(length($LOGDIR) > 0) {
	if(! -d "$LOGDIR/bld") {
	    mkpath "$LOGDIR/bld";
	}
	chdir "${EXEROOT}" or $logger->logdie ("Could not cd to ${EXEROOT}: $!");
	foreach my $log(@bldlogs) {
	    system("gzip $log");
	}	
	my @gzlogs = glob("${EXEROOT}/*bldlog.$LID.*");
	foreach my $gzlog(@gzlogs) {
	    copy($gzlog, "$LOGDIR/bld");
	}
    }
	
    chdir "$CASEROOT" or $logger->logdie("Could not cd to $CASEROOT: $!");
    
    $sysmod = "./xmlchange BUILD_COMPLETE=TRUE";
    system($sysmod) == 0 or $logger->logdie("$sysmod failed: $?");
    
    $sysmod = "./xmlchange BUILD_STATUS=0";
    system($sysmod) == 0 or $logger->logdie("$sysmod failed: $?");
    
    $sysmod = "./xmlchange SMP_BUILD=$SMP_VALUE";
    system($sysmod) == 0 or $logger->logdie("$sysmod failed: $?");
    
    $sysmod = "./xmlchange NINST_BUILD=$NINST_BUILD";
    system($sysmod) == 0 or $logger->logdie("$sysmod failed: $?");
    
    my @files2unlink = glob("./LockedFiles/env_build*");
    foreach my $file2unlink(@files2unlink) {
	unlink($file2unlink);
    }
	
    foreach my $file (qw( ./env_build.xml ) ) {
	copy($file, "./LockedFiles/$file.locked");
	if ($?) { $logger->logdie("ERROR locking file $file, exiting.. ");}
	$logger->info( " .... locking file $file");
    }
    
    my $sdate = `date +"%Y-%m-%d %H:%M:%S"`;
    open my $CS, ">>", "./CaseStatus";
    print $CS "build complete $sdate\n";
    close $CS;
}

main() unless caller; 


#!/usr/bin/perl

#
# git_svn_externals.pl
#
# Author:
#  Dmitry Sushko <Dmitry.Sushko@yahoo.com>
#

use strict;
use warnings;
use Cwd;
use File::Path;
use File::Basename;
use Term::ANSIColor;

my $git_executable         = "git";
my $git_directory          = ".git";
my $git_externals_dir      = ".git_externals";
my $show_externals_command = "$git_executable svn show-externals";
my $clone_external_command = "$git_executable svn clone";
my $git_svn_pull_command   = "$git_executable svn fetch && $git_executable svn rebase";
my $git_svn_fetch_command  = "$git_executable svn fetch";
my $git_svn_rebase_command = "$git_executable svn rebase";
my $git_get_svn_url = "git svn info --url";
my $svn_log_command = "svn log -l 1 -r ";

sub IsGitRepository {
	if (-d $git_directory) {
		return 1;
	} else {
		return 0;
	}
}

sub Exec
{
	my ($cmd) = @_;
	
#	print " *************************************** RUNNING: $cmd \n";
	
	my $ret = qx/$cmd/;
	
#	print " *************************************** RETURN: $ret \n";
	
	return $ret;
}

sub ExecArr
{
	my ($cmd) = @_;
	
#	print " *************************************** RUNNING: $cmd \n";
	
	my @ret = qx/$cmd/;
	
#	print " *************************************** RETURN: " . scalar(@ret) . " lines \n";
#	print @ret;
	
	return @ret;
}

sub GetValidRevisionFromSvn {
    my $url = shift;
    my $revision = shift;
    print colored['red'], "Verifying last valid revision from : " . $url . "\n";
    my $info_cmd = $svn_log_command . " " . $$revision . ":1 " . $url;
    print colored['red'], "Executing : " . $svn_log_command . "\n";
    my @last_revision = qx($info_cmd);

    $last_revision[1] =~ m/^r([0-9]+)/;
    $$revision = $1;
}

sub GitSvnCloneExternal {
	my ($ext_path, $ext_url, $ext_rev) = @_;
	$ext_rev ||= "";
	if($ext_rev ne "") {
	    print colored['red'], "DBG: Old revision: " . $ext_rev . "\n";
	    GetValidRevisionFromSvn($ext_url, \$ext_rev);
	    print colored['red'], "DBG: New revision: " . $ext_rev . "\n";
	}

	my $ext_basename = basename($ext_path);
	my $ext_dirname  = dirname($ext_path);

	$ext_basename =~ s/%20/ /g;
	$ext_basename =~ s/\\//g;
	$ext_dirname  =~ s/%20/ /g;
	$ext_dirname  =~ s/\\//g;

	$ext_path =~ s/%20/ /g;
	$ext_path =~ s/\\//g;

	print "NFO: Dirname = [$ext_dirname], Basename = [$ext_basename]\n";

	mkpath $ext_dirname or die "Error: $!\n" unless -d $ext_dirname;

	mkpath $git_externals_dir or die "Error: $!\n" unless -d $git_externals_dir;

	my $ext_full_dirname = join ("/", $git_externals_dir, $ext_dirname);
	mkpath $ext_full_dirname or die "Error: $!\n" unless -d $ext_full_dirname;

	my $tmp_current_working_dir = cwd();

	chdir $ext_full_dirname or die "Error: $!\n";

	unless (-d $ext_basename) {
		print "NFO: External directory doesn't exist\n";
		# external directory doesn't exist
		if ($ext_rev =~ m/^$/) {
			Exec($clone_external_command . " " . $ext_url . " " . quotemeta($ext_basename));
		} else {
			Exec($clone_external_command . " --revision=" . $ext_rev . " " . $ext_url . " " . quotemeta($ext_basename));
		}
	} else {
		print "NFO: External directory exists\n";
		# directory already exists
		my $tmp_wd = cwd();
		chdir $ext_basename or die "Error: $!\n";
		
		my $is_git_repo = IsGitRepository();
		
		if ($is_git_repo) 
		{
			my $old_url = Exec($git_get_svn_url);
			$old_url =~ s/\n$//;
			
			if ($old_url ne $ext_url)
			{
				print "NFO: Changed svn url for this path: [$old_url] - [$ext_url]\n";
				print "NFO: Deleting old files and fetching again\n";
				
				chdir $tmp_wd or die "Error: $!\n";
				
				unlink($tmp_current_working_dir . "/" . $ext_dirname . "/" . $ext_basename);
				rmtree($ext_basename) or die "Error: $!\n";
				
				$is_git_repo = 0;
			}
		}
		
		if ($is_git_repo) {
			print "NFO: External already cloned, updating\n";
			if ($ext_rev =~ m/^$/) {
				Exec($git_svn_pull_command);
			} else {
				Exec($git_svn_pull_command);
				# now find the git commit sha of the interesting revision
				my $git_svn_rev = $ext_rev;
				$git_svn_rev =~ s/(-|\s)//g;
				#print "DBG: git_svn_rev = $git_svn_rev\n";
				my $git_sha = Exec("git svn find-rev r$git_svn_rev");
				$git_sha =~ s/\n//;
				#print "DBG: found git sha: $git_sha\n";
				Exec("$git_executable checkout master");
				Exec("$git_executable branch -f __git_ext_br $git_sha");
				Exec("$git_executable checkout __git_ext_br");
			}
			chdir $tmp_wd or die "Error: $!\n";
		} else {
			chdir $tmp_wd or die "Error: $!\n";
			if ($ext_rev =~ m/^$/) {
				Exec($clone_external_command . " " . $ext_url . " " . quotemeta($ext_basename));
			} else {
				Exec($clone_external_command . " --revision=" . $ext_rev . " " . $ext_url . " " . quotemeta($ext_basename));
			}
		}
	}

	my $tmp_ext_dir = $tmp_current_working_dir . "/" . $ext_dirname;
	chdir $tmp_ext_dir or die "Error: $!\n";
	my $git_repo_root_dir = Exec("git rev-parse --show-cdup");
	$git_repo_root_dir =~ s/\n$//;
	my $link_to_dir = $git_repo_root_dir . $git_externals_dir . "/" . $ext_path;
	print "DBG: Linking $link_to_dir -> $ext_basename\n";
	print "CWD: " . cwd() . "\n";

   my $osname = $^O;
   if( $osname eq 'MSWin32' ) {
      Exec("mklink \/j \"$ext_basename\" \"$link_to_dir\"");
   } elsif( $osname eq 'cygwin' ) {
       my $ext_basename_backslash = $ext_basename;
       $ext_basename_backslash =~ s/\//\\/g;
       my $link_to_dir_backslash = $link_to_dir;
       $link_to_dir_backslash =~ s/\//\\/g;
      print "cygstart c:\/windows\/system32\/cmd \/c mklink \/D \"$ext_basename_backslash\" \"$link_to_dir_backslash\"";
      Exec("cygstart c:\/windows\/system32\/cmd \/c mklink \/D \"$ext_basename_backslash\" \"$link_to_dir_backslash\"");
   } else {
      Exec("ln -snf \"$link_to_dir\" \"$ext_basename\"");
   }
	# exclude external from current git
	chdir $tmp_current_working_dir or die "Error: $!\n";

	# Populate hash with possible excludes
	my %pending_excludes = ( $git_externals_dir => 1, $ext_path => 1 );

	open GITEXCLUDE, "<", ".git/info/exclude";
	while (my $line = <GITEXCLUDE>) {
		if ($line =~ m/^$git_externals_dir\n$/) {
			delete $pending_excludes{$git_externals_dir};
		}
		if ($line =~ m/^$ext_path\n$/) {
			delete $pending_excludes{$ext_path};
		}
	}
	close GITEXCLUDE;

	open (GITEXCLUDE, ">>.git/info/exclude") or die "Error: $!\n";
	for my $exclude (keys %pending_excludes) {
		print GITEXCLUDE "$exclude\n";
	}
	close GITEXCLUDE;
	
	# recursive check for externals
	my $external_working_dir = $tmp_current_working_dir."/".$git_externals_dir."/".$ext_dirname."/".$ext_basename;
	chdir $external_working_dir or die "Error: $!\n";
	
	&ListGitSvnExternals($ext_rev);

	chdir $tmp_current_working_dir or die "Error: $!\n";
}

sub Trim
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub ExternalWithRevisionMatches {

   my $external = shift;
	my $ext_path = shift;
	my $ext_url = shift;
	my $ext_rev = shift;

   if ($external =~ m/(.+)\s-r\s*(\S+)\s+((file:|http:|https:|svn:|svn\+ssh:)\S+)/) {

      # found an external with revision specified
      $$ext_path = $1;
      $$ext_rev  = $2;
      $$ext_url  = $3;
      $$ext_path =~ s/\///;
      return 1;
   }
   elsif ($external =~ m/((file:|http:|https:|svn:|svn\+ssh:)\S+)@(.+)\s(.+)/) {
      # found an external with revision specified
      $$ext_path = $4;
      $$ext_rev  = $3;
      $$ext_url  = $1;
      $$ext_path =~ s/\///;
      return 1;
   }

   return 0;
}

sub ExternalWithoutRevisionMatches {

   my $external = shift;
   my $ext_path = shift;
   my $ext_url = shift;

   if ($external =~ m/(.+)\s((file:|http:|https:|svn:|svn\+ssh:)\S+)/) {
      # found an external without revision specified
      $$ext_path = $1;
      $$ext_url  = $2;
      $$ext_path =~ s/\///;
      return 1;
   }
   elsif ($external =~ m/((file:|http:|https:|svn:|svn\+ssh:)\S+)\s(\S+)/) {
       # found an external without revision specified
      $$ext_path = $3;
      $$ext_url  = $1;
      #$ext_path =~ s/\///;
      return 1;
   }

   return 0;
}

sub ExternalMatches {

   my $external = shift;

   my $ext_path = ""; 
   my $ext_url = "";
   my $ext_rev = "";

   if (ExternalWithRevisionMatches($external, \$ext_path, \$ext_url, \$ext_rev)) {

      print colored ['green'],
      "==================================================\n";
      print colored ['cyan'],
      "External found:\n" .
      "   path: $ext_path\n" .
      "   rev : $ext_rev\n" .
      "   url : $ext_url\n";

      &GitSvnCloneExternal ($ext_path, $ext_url, $ext_rev);
      return 1;
   }
   elsif (ExternalWithoutRevisionMatches($external, \$ext_path, \$ext_url)) {

      # found an external without revision specified
      print colored ['green'],
      "==================================================\n";
      print colored ['cyan'],
      "External found:\n" .
      "   path: $ext_path\n" .
      "   url : $ext_url\n";
      &GitSvnCloneExternal ($ext_path, $ext_url);
      return 1;
   }
   return 0;
}

sub ListGitSvnExternals {
	my ($ext_rev_base) = @_;
	$ext_rev_base ||= "";

	my @show_externals_output;
	if ($ext_rev_base =~ m/^$/) {
		@show_externals_output = ExecArr($show_externals_command);
	} else {
		@show_externals_output = ExecArr($show_externals_command . " --revision=" . $ext_rev_base);
	}

	my $line;
	my @externals;
	foreach $line (@show_externals_output) {
		$line =~ s/\n$//;
		$line =~ s/#.*$//;
		$line = Trim($line);

		next if ($line =~ m/^$/ || $line =~ m/^\e\[.*$/);
		print "DBG: Found external: $line\n";
		push(@externals, $line);
	}

	my @external_hashes;
	my $external;
	my $ext_path;
	my $ext_rev;
	my $ext_url;
	foreach $external (@externals) {

	    unless (ExternalMatches($external)) {
		print colored ['red'], "ERR: Malformed external specified: $external\n";
		next;
	    }
	}
}

&ListGitSvnExternals();

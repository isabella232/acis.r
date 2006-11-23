package ACIS::APU;

=head1 NAME

ACIS::APU -- Automatic Profile Update

=cut

#
#  This module is a partial replacement for ACIS::Web::ARPM
#  and ACIS::Web::ARPM::Queue.
#

use strict;
use warnings;
use Exporter;
use Carp;
use Carp::Assert;
use Web::App::Common qw( debug );
use sql_helper;

use base qw( Exporter );
use vars qw( $ACIS @EXPORT_OK @EXPORT @ISA );
*ACIS = *ACIS::Web::ACIS;
@EXPORT = qw( logit set_queue_item_status push_item_to_queue );
@ISA = qw(Exporter);

use ACIS::APU::Queue;


my $interactive;
my $logfile;

sub logit (@) {
  if ( not $logfile and $ACIS ) {
    $logfile = $ACIS -> home . "/autoprofileupdate.log";
  }

  if ( $logfile ) {
    open LOG, ">>:utf8", $logfile;
    print LOG scalar localtime(), " [$$] ", @_, "\n";
    close LOG;

  } else {
    warn "can't logit: @_";
  }

  if ( $interactive ) {
    print @_, "\n";
  }
}

my $error_count = 0;
sub error {
  my $message = shift;
  logit "ERR: $message";
  if ( $error_count > 15 ) {
    die "too many errors";
  }
  $error_count ++;
}


# resolve long id & short id into email address of the owner

sub get_login_from_queue_item {
  my $sql = shift;
  my $item = shift;
  my $login;
 
  if ( length( $item ) > 8 
       and $item =~ /^.+\@.+\.\w+$/ ) {

    $sql -> prepare( "select owner from records where owner=?" );
    my $r = $sql -> execute( lc $item );
    if ( $r and $r -> {row} ) {
      $login = $r ->{row} {owner};
      
    } else {
      logit "get_login_from_queue_item: email $item not found";
    }

  } else {
    if ( length( $item ) > 15
         or index( $item, ":" ) > -1 ) {
      $sql -> prepare( "select owner from records where id=?" );
      my $r = $sql -> execute( lc $item );
      if ( $r and $r -> {row} ) {
        $login = $r ->{row} {owner};
      } else {
        logit "get_login_from_queue_item: id $item not found";
      }

    } elsif ( $item =~ m/^p[a-z]+\d+$/ 
              and length( $item ) < 15 ) {
      $sql -> prepare( "select owner,id from records where shortid=?" );
      my $r = $sql -> execute( $item );
      if ( $r and $r -> {row} ) {
        $login = $r ->{row} {owner};

      } else {
        logit "get_login_from_queue_item: sid $item not found";
      }
    }
  }

  return $login;
}





sub run_apu_by_queue {
  my $chunk = shift || 3;
  my %para  = @_;
  my $auto_restart_queue = $para{-auto}   || 0;
  my $failed_ones        = $para{-failed} || 0;
  $interactive           = $para{-interactive};
  
  $ACIS || die;
  my $sql = $ACIS->sql_object || die;

  my $number = $chunk;
  
  if ( $failed_ones ) {
    logit "would only take previously failed queue items";
  }

  while ( $number ) {
    my ($qitem, $class) = get_next_queued_item( $sql );

    if ( $failed_ones ) {
      ($qitem, $class) = get_next_failed_queued_item( $sql );
    }

    if ( not $qitem ) {
      logit "no more items in the queue";
      if ( $auto_restart_queue ) {
        logit "reinitialize the queue";
        clear_the_queue_table( $sql );
        fill_the_queue_table( $sql );
        $auto_restart_queue = 0;
        next;
      } else {
        logit "quitting";
        last; 
      }
    }

    my $login = get_login_from_queue_item( $sql, $qitem );
    my $rid   = $qitem;
    my $res;
    my $notes;

    if ( $login ) {

      if ( $rid ne $login ) { 
        logit "about to process: $rid ($login)";
      } else {
        logit "about to process: $login";
      }
      
      require ACIS::Web::Admin;

      eval {
        ###  get hands on the userdata (if possible),
        ###  create a session and then do the work

        ###  XXX $qitem is not always a record identifier, but
        ###  offline_userdata_service expects an indentifier if anything on
        ###  4th parameter position
        $res = ACIS::Web::Admin::offline_userdata_service
                        ( $ACIS, $login, 'ACIS::APU::record_apu', $rid ) 
                        || 'no';
      };
      if ( $@ ) {
        $res   = "FAIL"; 
        $notes = $@;
      }

      logit "apu for $login/$rid result: $res";
      if ( $notes ) {
        logit "notes: $notes";
      }

      set_item_processing_result( $sql, $rid, $res, $notes );
      if ( $res ne 'SKIP' ) { $number--; }
      
    } else {
      last; 
    }

  } continue {
    $ACIS -> clear_after_request();
  }
}





use ACIS::Web::SysProfile;
require ACIS::Web::ARPM;
use ACIS::Citations::AutoUpdate;

sub record_apu {
  my $acis = shift;

  my $session = $acis -> session;
  my $vars    = $acis -> variables;
  my $record  = $session -> current_record;
  my $id      = $record ->{id};
  my $sid     = $record ->{sid};
  my $sql     = $acis -> sql_object;

  my $pri_type = shift;
  my $pretend  = shift || $ENV{ACIS_PRETEND};

  if ( $record -> {pref} {'disable-apu'} ) { return "SKIP"; }

  my $now = time;
  my $last_research  = get_sysprof_value( $sid, 'last-autosearch-time' );
  my $last_citations = get_sysprof_value( $sid, 'last-auto-citations-time' );
  my $last_apu       = get_sysprof_value( $sid, 'last-apu-time' );

  my $apu_too_recent_days  = $ACIS->config( 'minimum-apu-period-days' ) || 21;
  my $apu_too_recent_seconds = $apu_too_recent_days * 24 * 60 * 60;

  if ( $now - $last_apu < $apu_too_recent_seconds ) {
    return "SKIP";
  }

  my $research;
  my $citations;
  
  # research
  if ( not $pri_type 
       or $pri_type eq 'research' 
       or not $last_research
       or ($now - $last_research >= $apu_too_recent_seconds/2)  
     ) {
    $research = 1;
    ACIS::Web::ARPM::search( $acis, $pretend );
  }

  # citations 
  if ( not $pri_type 
       or $pri_type eq 'citatitons' 
       or not $last_citations
       or ($now - $last_citations >= $apu_too_recent_seconds/2)  
     ) {
    $citations = 1;
    ACIS::Citations::AutoUpdate::auto_processing( $acis, $pretend );
  }

  if ( $citations or $research ) {
    put_sysprof_value( $sid, 'last-apu-time', $now );
  } else {
    return "SKIP";
  }

  return "OK";
}



sub testme {
  $interactive = 1;

  use ACIS::Web;
  my $acis = ACIS::Web->new();

  die if not $ACIS;
  my @queue = get_the_queue( 5 );
}



1;

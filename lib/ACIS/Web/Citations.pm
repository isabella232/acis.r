package ACIS::Web::Citations;

use strict;
use warnings;
use Carp qw( confess );
use Carp::Assert;

use Web::App::Common;

use ACIS::Citations::Utils;
use ACIS::Citations::Suggestions qw( suggest_citation_to_coauthors );
use ACIS::Citations::SimMatrix;
use ACIS::Citations::Search;


my $acis;
my $sql;
my $session;
my $vars;
my $id;
my $sid;
my $record;
my $params;
my $document;
my $dsid;
my $citations;
my $research_accepted;
my $mat;

sub get_doc_by_sid ($) {
  my $dsid = $_[0] || return undef;
  foreach ( @{ $research_accepted } ) {
    if ( $_->{sid} eq $dsid ) { 
      return $_;
    }    
  }
  return undef;
}


sub prepare() {
  $acis = $ACIS::Web::ACIS;
  die "citations not enabled system-wide" 
    if not $acis->config( 'citations-profile' );

  $sql  = $acis -> sql_object;

  $session = $acis -> session;
  $vars    = $acis -> variables;
  $record  = $session -> current_record;
  $id      = $record ->{id};
  $sid     = $record ->{sid};

  $params = $acis->form_input;

  $citations         = $record ->{citations} ||= {};
  $research_accepted = $record ->{contributions}{accepted} || [];

  $mat = $session ->{simmatrix} ||= load_similarity_matrix( $sid ); 
  $mat = load_similarity_matrix( $sid ); # XXX ||=
  $mat -> upgrade( $acis, $record );

  $dsid = $params->{dsid} || $acis->{request}{subscreen};
  if ( $dsid ) {
    $document = get_doc_by_sid $dsid;
  }

}





sub prepare_citations_list($) {
  # prepare new citations list
  my $srclist = shift;
  my $list = []; 
  my $index = {};
  foreach ( @$srclist ) {
    if ( $_ ->{reason} eq 'similar'      # this condition may be unnecessary
         and $_->{similar} < min_useful_similarity ) { next; }
    my $cid = cid $_;
    if ( $index->{$cid} ) {
      $index->{$cid}{similar} += $_->{similar};
    } else {
      my $cit = { %$_ };
      push @$list, $cit;
      $index->{$cid} = $cit;
    }
  }
  @$list = sort { $b->{similar} <=> $a->{similar} } @$list;
  return $list;
}

sub count_significant_potential ($) {
  my $list = $_[0];
  my $count = 0;
  my $index = {};
  my $minsim = min_useful_similarity;
  foreach ( @$list ) {
    if ( $_ ->{reason} eq 'similar'      # this condition may be unnecessary
         and $_->{similar} < $minsim ) { next; }
    my $cid = cid $_;
    next if $index->{$cid};
    $index ->{$cid} = 1;
    $count++;
  }
  return $count;
}



sub prepare_potential {
  die "no document sid to show citations for" if not $dsid;
  die "can't find that document: $dsid" if not $document;

  debug "prepare_potential()";
  my $citations_new = $mat->{new}{$dsid};
  my $citations_old = $mat->{old}{$dsid};

  $vars -> {document} = $document;
  $vars -> {potential_new} = prepare_citations_list $citations_new;
  $vars -> {potential_old} = prepare_citations_list $citations_old;

  prepare_prev_next();

  foreach ( qw( citation-document-similarity-preselect-threshold ) ) {
    $acis->variables->{$_} = $acis->config( $_ ) * 100;
  }

}




sub process_potential {
  shift;
  die "no document sid to show citations for" if not $dsid;
  die "can't find that document: $dsid" if not $document;

  my %cids = ();
  my @adds;
  my @refusals;
  
  foreach ( keys %$params ) {
    if ( m/add(.+)/ ) { push @adds, $1; }
    if ( m/refuse(.+)/ ) { push @refusals, $1; }
    if ( m/cid(.+)/ ) { $cids{$1} = $params->{"cid$1"}; }
  }
 
  if ( scalar @refusals ) {
    return process_refuse( \%cids, \@adds, \@refusals );
  }

  my $added = 0;
  foreach ( @adds ) {
    my $cid = $cids{$_};
    debug "add citation $cid to $dsid";
    if ( not $cid ) { debug "no cid in form data; ignoring citation add: $_"; next; }

    # identify a citation
    my $list = ($mat->{citations}{$cid}) ? $mat -> {citations}{$cid}{$dsid} : next;
    my $cit  = ($list and $list->[0]) ? $list->[0][1] : next; 

    $mat -> remove_citation( $cit );
    identify_citation_to_doc($record, $dsid, $cit);
    suggest_citation_to_coauthors( $cit, $sid, $dsid );
    $added ++;
  }

  if ( $added > 1 ) {     $acis->message( "added-citations" ); }
  elsif ( $added == 1 ) { $acis->message( "added-citation"  ); }


  my $nlist = $mat->{new}{$dsid} || [];
  foreach( keys %cids ) {
    # old citations' cidX parameters are named cidXo,
    # therefore, if we have a digit at the end, it is a new
    # citation.  unless the user used a stale webform
    if ( # m/\d+$/ and 
         not defined $params->{"add$_"} ) {
      my $cid = $cids{$_};
      my $cit; 
      foreach (@$nlist) { my $id = cid $_; if ($id eq $cid) {$cit = $_;last;} }
      if ( $cit ) {
        $mat -> citation_new_make_old( $dsid, $cit );
      }
    }
  }


  my $autosug = $acis->{request}{screen} eq 'citations/autosug';
  if ( $params->{moveon} ) {
    if ( $autosug ) {
    } else {
      $acis->redirect_to_screen( 'citations/autosug' );
    }
  } 
}




# process_refuse( \%cids, \@adds, \@refusals );
sub process_refuse {
  my $cids = shift;
  my $adds = shift;
  my $refuse = shift;

  my $counter;
  foreach( @$refuse ) {
    my $cid = $cids->{$_};
    debug "refuse citation $cid (for $dsid)";
    if ( not $cid ) { debug "no cid in form data; ignoring citation refuse: $_"; next; }

    # identify a citation
    my $list = ($mat->{citations}{$cid}) ? $mat -> {citations}{$cid}{$dsid} : next;
    my $cit  = ($list and $list->[0]) ? $list->[0][1] : next; 

    $mat -> remove_citation( $cit );
    refuse_citation($record, $cit);
    $counter ++;
  }

  if ( $counter > 1 ) {     $acis->message( "refused-citations" ); } 
  elsif ( $counter == 1 ) { $acis->message( "refused-citation"  ); }
  
  my $preselect = [];
  foreach( keys %$cids ) {
    if ( defined $params->{"add$_"} ) {
      my $cid = $cids->{$_};
      push @$preselect, $cid;
    }
  }
  $vars->{'preselect-citations'} = $preselect; 
}


sub prepare_identified {
  die "no document sid to show citations for" if not $dsid;
  die "can't find that document: $dsid" if not $document;

  $vars -> {document}   = $document;
  $vars -> {identified} = $citations->{identified}{$dsid};

  prepare_prev_next();
}


use Carp::Assert;

sub process_identified {
  die "no document sid to show citations for" if not $dsid;
  die "can't find that document: $dsid" if not $document;
  
  my %cids;
  my @delete = ();

  foreach ( keys %$params ) {
    if ( m/del(.+)/ ) { push @delete, $1; }
    if ( m/cid(.+)/ ) { $cids{$1} = $params->{"cid$1"}; }
  }

  my @citations;
  foreach ( @delete ) {
    my $cid = $cids{$_};
    my $cit = unidentify_citation_from_doc_by_cid( $record, $dsid, $cid );

    assert( $cit->{ostring} );
    $cit->{nstring} = make_citation_nstring $cit->{ostring};
    assert( $cit->{nstring} );
    assert( $cit->{srcdocsid} );
    if ( $cit ) {
      warn("gone!"), delete $cit->{gone} if $cit->{gone};
      push @citations, $cit;
    }
  }
  $mat -> add_new_citations( \@citations );

  if ( scalar @citations > 1 )  {    $acis -> message( "deleted-citations" ); }
  elsif ( scalar @citations == 1 ) { $acis -> message( "deleted-citation"  ); }
}



sub prepare_doclist {
  my $docsidlist = $mat->{doclist};
  my $doclist = $vars ->{doclist} = [];
  my $ind = {};
  foreach ( @$docsidlist ) {
    my $d = get_doc_by_sid $_;
    confess "document not found: $_" if not $d;
    my $new = prepare_citations_list $mat->{new}{$_};
    my $old = prepare_citations_list $mat->{old}{$_};
    my $id  = $citations->{identified}{$_} || [];
    my $simtotal = $mat->{totals_new}{$_};
    
    push @$doclist, { doc => $d, 
                      new => scalar @$new, 
                      old => scalar @$old, 
                      id  => scalar @$id,
                      similarity => $simtotal };
    $ind->{$_} = 1;
  }

  my @tmp;
  foreach ( @$research_accepted ) {
    my $d   = $_;
    my $dsid = $_->{sid};
    next if $ind->{$dsid};

    my $id  = $citations->{identified}{$dsid} || [];
    my $old = prepare_citations_list $mat->{old}{$dsid};
    push @tmp, { doc => $d, 
                 old => scalar @$old, 
                 id  => scalar @$id,
               };
  }
  @tmp = sort { $b->{id} <=> $a->{id} 
                or $b->{old} <=> $a->{old} } @tmp;
  push @$doclist, @tmp;
  
  my $identified_num = 0;
  foreach (@$doclist) {
    $identified_num += $_->{id};
  }
  $vars ->{'identified-number'} = $identified_num;
  $vars ->{'potential-new-number'} = $mat->number_of_new_potential;  
}

sub prepare_autosug {

  if ( $dsid and $params->{moveon} 
       or not $dsid ) {
    my $docsidlist = $mat->{doclist};
    $dsid = $docsidlist->[0];
    if ( $dsid ) {
      $document = get_doc_by_sid $dsid;
    }
  }
  
  if ( $document ) {
    prepare_potential();
  } else {
    $vars->{'most-interesting-doc'} = 't';
  }

  debug "not the most interesting!" if not $vars->{'most-interesting-doc'};
}

sub process_autosug {
  process_potential;
}

sub prepare_overview {
  prepare_doclist;
  my $ref = $citations->{refused} ||=[];  
  $vars ->{'refused-number'} = scalar @$ref;
}


sub prepare_refused {
  $vars ->{refused} = $citations->{refused} ||=[];
}

sub process_refused {
  my %cids;
  my @delete = ();

  foreach ( keys %$params ) {
    if ( m/del(.+)/ ) { push @delete, $1; }
    if ( m/cid(.+)/ ) { $cids{$1} = $params->{"cid$1"}; }
  }

  my @citations;
  foreach ( @delete ) {
    my $cid = $cids{$_};
    my $cit = unrefuse_citation_by_cid( $record, $cid );

    assert( $cit->{ostring} );
    $cit->{nstring} = make_citation_nstring $cit->{ostring}
      if not $cit->{nstring};
    assert( $cit->{nstring} );
    assert( $cit->{srcdocsid} );
    if ( $cit ) {
      warn("gone!"), delete $cit->{gone} if $cit->{gone};
      push @citations, $cit;
    }
  }
  $mat -> add_new_citations( \@citations );

  if ( scalar @citations > 1 )  {    $acis -> message( "unrefused-citations" ); }
  elsif ( scalar @citations == 1 ) { $acis -> message( "unrefused-citation" );  }

}


sub prepare_prev_next {
  die "no document sid to show citations for" if not $dsid;
  die "can't find that document: $dsid" if not $document;

  debug "prepare_prev_next()";

  my $docsidlist = $mat->{doclist};
  my $prev;
  my $next;
  my $found;
  foreach ( @$docsidlist ) {
    if ( $found ) {
      $next = $_;
      last;
    }
    if ( $_ eq $dsid ) {
      $vars->{previous} = $prev  if $prev;
      $found = 1;
    }
    $prev = $_;
  }
    
  $vars ->{next} = $next  if $next;

  if ( $found and not $vars->{previous} ) {
    $vars->{'most-interesting-doc'} = 't';
    debug "most interesting doc";
  }

  if ( scalar @$docsidlist ) {
    $vars->{'anything-interesting'} = 't';
  }
}

sub prepare_research_identified {
  my $rc = {}; # reseach citations
  my $ci = $citations->{identified};
  my $ri = $vars->{contributions}{accepted};
  foreach ( @$ri ) {
    my $dsid = $_->{sid};
    next if not $dsid;
    if ( $ci->{$dsid} ) {
      $rc->{identified}{$dsid} = scalar @{ $ci->{$dsid} };
    }
    my $pot = count_significant_potential $mat->{new}{$dsid};
    if ( $pot ) {
      $rc->{potential}{$dsid} = $pot;
    }
  }
  if ( scalar keys %$rc ) {
    $vars -> {contributions}{citations} = $rc;
  }
}


1;

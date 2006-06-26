package RePEc::Index::Collection::CitationsAMF;

use strict;

use base qw( RePEc::Index::Collection::AMF );
require RePEc::Index::Collection;

use AMF::Parser;

sub get_next_record {
  my $self = shift;
  my $r;
  
  START: $r = amf_get_next_noun;

  if ( $r ) {

    my $id = $r ->ref;
    my $cr = extract_citations( $r );

    if ( scalar @$cr == 1 ) { undef $cr; }
    if ( not $id or not $cr ) { goto START; }

    my $start = 0;
    my $md5  = $cr -> md5checksum;

    return ( "$id#citations", $cr, "citations", $start, $md5 );

  } else {
    return undef;
  }
}

 

sub check_id {
  return 1;
}


sub make_monitor_file_checker { 
  return sub { 
    if ( m/\.amf\.xml$/i ) {  return 1; }
    else { return 0; }
  }
}



my @cits;

sub new_citation($;$) {
  my $ostring  = shift;
  my $trgdocid = shift;

  $ostring =~ s/^\s+//g;
  $ostring =~ s/\s+$//g;
  
  my $c = { ostring => $ostring };
  if ( $trgdocid ) {
    $c ->{trgdocid} = $trgdocid;
#    print "citation '$ostring' points to: '$trgdocid'\n";

  } else {
#    print "unidentified citation '$ostring'\n";
  }

  push @cits, $c;
}

sub extract_citations ($) {
  my $text = shift;
  
  @cits = ();

  my $id = $text -> get_value( 'REF' );

  push @cits, $id;

  my $string;
  my $target;

  # identified citations
  my $identfd = $text -> {references};
  foreach ( @$identfd ) {
    
    if ( $string and $target ) {
      new_citation( $string, $target );
      undef $string;
      undef $target;
    }

    if ( UNIVERSAL::isa( $_->[0], 'AMF::Noun' )) {
      $target = $_->[0]->ref;
    } elsif ( $_->[0] eq 'http://acis.openlib.org/ referencestring' ) {
      $string = $_->[2][0];
    }
  }
  
  if ( $string and $target ) {
    new_citation( $string, $target );
  }
  
  # unidentified citations
  my @unidentfd = $text->get_value( 'reference/literal' );
  foreach ( @unidentfd ) {
    my $string = $_;
    new_citation( $string );
  }


  my $o = bless \@cits, "ACIS::CitationsList";
  return $o;
}


package ACIS::CitationsList;

sub id {
  my $self = shift;
  return $self->[0];
}

sub type { 
  my $self = shift;
  return "citations";
}

use Digest::MD5;

sub md5checksum {
  my $self = shift;
  my $id = $self->[0];

  my $ctx = Digest::MD5->new;
  $ctx -> add( "$id\n" );
  foreach ( @$self ) {
    if ( not ref( $_ ) ) { next; }
    
    my $s = " ";
    $s .= $_->{ostring};
    if ( $_->{trgdocid} ) {
      $s .= '@';
      $s .= $_->{trgdocid};
    }
    $s .= "\n";
    
    $ctx -> add( $s );
  }
  return $ctx->b64digest;
}

1;
<?xml version="1.0" encoding="utf-8"?>
<!--   This file is part of the ACIS presentation template-set.   -->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:exsl="http://exslt.org/common"
    xmlns:acis="http://acis.openlib.org"
    xmlns:html="http://www.w3.org/1999/xhtml"
    exclude-result-prefixes="exsl xsl html acis"
    version="1.0">  

  <xsl:import href='general.xsl'/>

  <xsl:template match='/data'
                name='arpm-notice'>
    <xsl:call-template name='format-message'>
      <xsl:with-param name='to'>
        <xsl:text>"</xsl:text>
        <xsl:value-of select='$user-name'/>
        <xsl:text>" &lt;</xsl:text>
        <xsl:value-of select='$user-login'/>
        <xsl:text>&gt;</xsl:text>
      </xsl:with-param>
      <xsl:with-param name='subject'>
        <xsl:text>automatic research profile update</xsl:text>
      </xsl:with-param>      
      <xsl:with-param name='content'>
        <xsl:call-template name='arpm-email'/>
      </xsl:with-param>      
    </xsl:call-template>
  </xsl:template>

  <!--  Some useful variables: -->
  <xsl:variable name='added-by-handle' 
                select='//added-by-handle/list-item'/>
  <xsl:variable name='added-by-handle-count' 
                select='count(//added-by-handle/list-item)'/>
  <xsl:variable name='suggest-by-handle' 
                select='//suggest-by-handle/list-item'/>
  <xsl:variable name='suggest-by-handle-count' 
                select='count(//suggest-by-handle/list-item)'/>
  <xsl:variable name='added-by-name' 
                select='//added-by-name/list-item'/>
  <xsl:variable name='added-by-name-count' 
                select='count(//added-by-name/list-item)'/>
  <xsl:variable name='suggest-by-name' 
                select='//suggest-by-name/list-item'/>
  <xsl:variable name='suggest-by-name-count' 
                select='count(//suggest-by-name/list-item)'/>
  <xsl:variable name='suggest-by-name-listed-first'
                select='number(//suggest-by-name-listed-first)'/>
  <xsl:variable name='suggest-by-name-total-number'  
                select='number(//suggest-by-name-total-number)'/>
  <xsl:variable name='anything-added'
                select='$added-by-handle-count + $added-by-name-count'/>
  <xsl:variable name='anything-suggest'
                select='$suggest-by-handle-count + $suggest-by-name-count'/>
  <xsl:variable name='anything-by-handle'
                select='$added-by-handle-count + $suggest-by-handle-count'/>
  <xsl:variable name='anything-by-name'
                select='$added-by-name-count + $suggest-by-name-count'/>               
  <xsl:variable name='both-bys'
                select='$anything-by-name and $anything-by-handle'/>
  <xsl:variable name='original-suggestions'
                select='//original-suggestions/list-item'/>
  <xsl:variable name='original-suggestions-count'
                select='count(//original-suggestions/list-item)'/>
  <!-- evcino: add a parameter to show relevance -->
  <xsl:variable name='with_relevance'
                select='count(//with_relevance_in_email)'/>

  <xsl:template name='list-works'>
    <xsl:param name='works'/>
    <ul>
      <xsl:for-each select='$works'>
        <li>
          <xsl:value-of select='title'/>
          <br/>
          <xsl:if test='authors'>
            <xsl:text> by </xsl:text>
            <xsl:value-of select='authors'/>
            <br/>
          </xsl:if>
          <xsl:if test='editors'>
            <xsl:text> edited by </xsl:text>
            <xsl:value-of select='editors'/>
            <br/>
          </xsl:if>
          <xsl:if test='url-about'>
            <xsl:value-of select='url-about'/>
            <br/>
          </xsl:if>
          <xsl:if test="$with_relevance">
            <xsl:choose>
              <xsl:when test='relevance'>
                <xsl:text> relevance: </xsl:text>
                <xsl:value-of select='relevance'/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text> NO RELEVANCE! </xsl:text>
              </xsl:otherwise>
            </xsl:choose>
            <br/>
          </xsl:if>
        </li> 
      </xsl:for-each>
    </ul>
  </xsl:template>

  <xsl:template name='arpm-email'>
    <!-- the next p is the crucial header/body separator -->
    <p/>
    <p>
      <xsl:text>Dear </xsl:text>
      <xsl:value-of select='$user-name'/>
      <xsl:text>,</xsl:text>
    </p>    
    <xsl:if test='$advanced-user'>
      <p>
        <xsl:text>Note: this message concerns the record of </xsl:text>
        <xsl:value-of select='$record-name'/>
        <xsl:text>(id: </xsl:text>
        <xsl:value-of select='$record-id'/>
        <xsl:text>, short-id: </xsl:text>
        <xsl:value-of select='$record-sid'/>
        <xsl:text>).</xsl:text>
      </p>
    </xsl:if>
    <p>
      <xsl:text>This is an automatic message from </xsl:text>
      <xsl:value-of select='$site-name-long'/>
      <xsl:text>.  You do not need to reply.</xsl:text>
    </p> 
    <xsl:apply-templates select='//added-by-handle'/>
    <xsl:apply-templates select='//suggest-by-handle'/>    
    <xsl:if test='not($suggest-by-name-count)'>
      <xsl:call-template name='invite-to-add-suggested'/>
    </xsl:if>   
    <xsl:if test='not($added-by-name-count)'>
      <xsl:call-template name='invite-to-fix-added'/>
    </xsl:if>
    <xsl:apply-templates select='//added-by-name'/>
    <xsl:apply-templates select='//suggest-by-name'/>
    <xsl:if test='$suggest-by-name-count'>
      <xsl:call-template name='invite-to-add-suggested'/>
    </xsl:if>
    <xsl:if test='$added-by-name-count'>
      <xsl:call-template name='invite-to-fix-added'/>
    </xsl:if>
    <xsl:apply-templates select='//original-suggestions'/>
    <xsl:if test='$anything-added and //saved-profiles//link'>
      <p>
        <xsl:text>Your updated profile is at its permanent address on the </xsl:text>
        <xsl:value-of select='$site-name-long'/>
        <xsl:text>:</xsl:text>
        <br/>
        <xsl:value-of select='//saved-profiles//link'/>
        <acis:phrase ref='email-arpm-after-saved-profile-link'/>
      </p>
    </xsl:if>    
    <p>
      <xsl:text>You may review and change your preferences with regard to automatic research profile updates at:</xsl:text>
      <br/> 
      <a>
        <xsl:attribute name='href'>
          <xsl:value-of select="$base-url"/>
          <xsl:text>/research/autoupdate</xsl:text>
        </xsl:attribute>
      <xsl:value-of select='$base-url'/>/research/autoupdate</a>
    </p>
    <xsl:if test='$user-pass and not($user-type/hide-password)'>
      <p>
        <xsl:text>Your password in our service is: </xsl:text>
        <xsl:value-of select='$user-pass'/>
      </p>
    </xsl:if>   
  </xsl:template>
  <xsl:template name='by-handle-intro'>
    <xsl:choose>
      <xsl:when test='$both-bys'>
        <xsl:text>First, we </xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>We </xsl:text>
      </xsl:otherwise>
    </xsl:choose>    
    <xsl:text>found that </xsl:text>
    <xsl:choose>
      <xsl:when test='$anything-by-handle > 1'>
        <xsl:text>descriptions of these documents point </xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>description of this document points </xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>to your personal record through its short-id. </xsl:text>    
  </xsl:template>      
  <xsl:template match='added-by-handle'>
    <p>
      <xsl:call-template name='by-handle-intro'/>
      <xsl:text> We have already added </xsl:text>
      <xsl:choose>
        <xsl:when test='$added-by-handle-count > 1'>
          <xsl:text>these documents </xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>this document </xsl:text>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:text>to your research profile:</xsl:text>
    </p>
    <xsl:call-template name='list-works'>
      <xsl:with-param name='works'
                      select='$added-by-handle'/>
    </xsl:call-template>
  </xsl:template>      
  <xsl:template name='found-by-name-intro'>    
    <xsl:choose>
      <xsl:when test='$both-bys'>
        <xsl:text>Second, we </xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>We </xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>ran an automatic search on our documents database for your name variations. We found </xsl:text>
    <xsl:choose>
      <xsl:when test='$anything-by-name > 1'>
        <xsl:text>these works, </xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>this work, </xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>which you might have authored:</xsl:text>
  </xsl:template>      
  <xsl:template match='suggest-by-name'>
    <p>
      <xsl:call-template name='found-by-name-intro'/>
    </p>
    <xsl:call-template name='list-works'>
      <xsl:with-param name='works' select='$suggest-by-name'/>
    </xsl:call-template>
    <xsl:if test='$suggest-by-name-listed-first'>
      <p>
        <xsl:text>(Listed above are the first </xsl:text>
        <xsl:value-of select='$suggest-by-name-listed-first'/>     
        <xsl:text>of total </xsl:text>
        <xsl:value-of select='$suggest-by-name-total-number'/>
        <xsl:text>items found.)</xsl:text>
      </p>
    </xsl:if>
  </xsl:template>      
  <xsl:template name='invite-to-add-suggested'>
    <xsl:if test='$anything-suggest'>
      <p>
        <xsl:text>If </xsl:text>
        <xsl:choose>
          <xsl:when test='$anything-suggest > 1'>
            <xsl:text>any of these documents </xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>this document </xsl:text>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text>is yours, you can add it to your profile on the research profile suggestions page:</xsl:text>
        <br/>
        <a>
          <xsl:attribute name='href'>
            <xsl:value-of select="$base-url"/>
            <xsl:text>/research/autosuggest</xsl:text>
          </xsl:attribute>
          <xsl:value-of select='$base-url'/>
          <xsl:text>/research/autosuggest</xsl:text>
        </a>
      </p>      
    </xsl:if>
  </xsl:template>
  <!-- this should not appear in AuthorClaim since there is no automated adding -->
  <xsl:template name='invite-to-fix-added'>
    <xsl:if test='$anything-added'>
      <p>
        <xsl:text>If </xsl:text>        
        <xsl:choose>
          <xsl:when test='$anything-added > 1'>
            <xsl:text>there's a mistake among the automatically added documents </xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>it was a mistake to add the above document to your profile, </xsl:text>
          </xsl:otherwise>
        </xsl:choose>        
        <xsl:text>you can fix it on the accepted works listing page of your research profile:</xsl:text>
        <br/>
        <a>
          <xsl:attribute name="href">
            <xsl:value-of select="$base-url"/>
            <xsl:text>/research/accepted</xsl:text>
          </xsl:attribute>
          <xsl:value-of select='$base-url'/>
          <xsl:text>/research/accepted</xsl:text>
        </a>
      </p>   
    </xsl:if>
  </xsl:template>
  <xsl:template match='original-suggestions'>
    <xsl:variable name='count' 
                  select='count(*)'/>    
    <xsl:if test='$count'>     
      <p>
        <xsl:text>BTW, you still have </xsl:text>
        <xsl:value-of select='$count'/>
        <xsl:text> other</xsl:text>        
        <xsl:choose>
          <xsl:when test='$count > 1'>
            <xsl:text> documents which were </xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text> document which was </xsl:text>
          </xsl:otherwise>
        </xsl:choose>        
        <xsl:text>found earlier but still wait</xsl:text>
        <xsl:if test='$count=1'>s</xsl:if>
        <xsl:text> for your decision.  See </xsl:text>
        <xsl:choose>
          <xsl:when test='$count > 1'>
            <xsl:text>them </xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>it </xsl:text>
          </xsl:otherwise>
        </xsl:choose>        
        <xsl:text>on your research profile's automatic search suggestions page.</xsl:text>        
      </p>
    </xsl:if>
  </xsl:template>      
</xsl:stylesheet>


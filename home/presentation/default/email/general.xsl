<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:exsl="http://exslt.org/common"
    xmlns:acis="http://acis.openlib.org"
    xmlns:html="http://www.w3.org/1999/xhtml"
    
    exclude-result-prefixes="exsl xml html acis"
    version="1.0"> 
  <xsl:import href='../global.xsl'/>
  <!-- evcino --> 
  <!-- for the link-filter mode -->
  <xsl:import href='../page.xsl'/>
  <xsl:output method='text' encoding='utf-8'/>
  <xsl:template name='message'>
    <xsl:param name='to'/>
    <xsl:param name='cc'/>
    <xsl:param name='bcc'/>
    <xsl:param name='subject'/>
    <xsl:param name='content'/>
    <xsl:text>From: </xsl:text>
    <xsl:value-of select='$config/system-email'/>
    <xsl:if test='string-length( $to )'>
      <xsl:text>&#10;</xsl:text>
      <xsl:text>To: </xsl:text>
      <xsl:value-of select='$to'/>
    </xsl:if>
    <xsl:if test='string-length( $cc )'>
      <xsl:text>&#10;</xsl:text>
      <xsl:text>CC: </xsl:text>
      <xsl:value-of select='$cc'/>
    </xsl:if>
    <xsl:if test='$bcc'>
      <xsl:text>&#10;</xsl:text>
      <xsl:text>BCC: </xsl:text>
      <xsl:value-of select='$bcc'/>
    </xsl:if>
    <xsl:text>&#10;</xsl:text>
    <xsl:text>Subject: [</xsl:text>
    <xsl:value-of select='$site-name'/>
    <xsl:text>] </xsl:text>
    <xsl:value-of select='$subject'/>
    <xsl:apply-templates select='exsl:node-set( $content )' 
                         mode='link-filter'/>    
    <xsl:call-template name='phrase'>
      <xsl:with-param name='ref'>email-footer</xsl:with-param>
    </xsl:call-template>
    <xsl:text>&#10;---&#10;&#10;All the details are on the </xsl:text>
    <xsl:value-of select='$site-name-long'/>
    <xsl:text> site: </xsl:text>
    <xsl:text>&#10;&#10;</xsl:text>
    <xsl:value-of select='$home-url'/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>
  <xsl:template name='format-message'>
    <xsl:param name='to'/>
    <xsl:param name='cc'/>
    <xsl:param name='subject'/>    
    <xsl:param name='content'/>
    <!-- header -->
    <xsl:if test='string-length( $to )'>
      <xsl:text>&#10;To: </xsl:text>
      <xsl:value-of select='$to'/>
    </xsl:if>
    <xsl:if test='string-length( $cc )'>
      <xsl:text>&#10;CC: </xsl:text>
      <xsl:value-of select='$cc'/>
    </xsl:if>
    <xsl:text>&#10;Subject: [</xsl:text>
    <xsl:value-of select='$site-name'/>
    <xsl:text>] </xsl:text>
    <xsl:value-of select='$subject'/>
    <xsl:text>&#10;</xsl:text>
    <!-- specially formatted body -->
    <xsl:call-template name='format-email'>
      <xsl:with-param name='data'>    
        <xsl:copy-of select='$content'/>
        <xsl:call-template name='phrase'>
          <xsl:with-param name='ref'>email-footer-html</xsl:with-param>
        </xsl:call-template>
      </xsl:with-param>    
    </xsl:call-template>
    <xsl:text>---&#10;The message was automatically generated by </xsl:text>
    <xsl:value-of select='$site-name-long'/>.
    <xsl:value-of select='$home-url'/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>
  <xsl:template name='format-email'>
    <xsl:param name='data'/>    
    <xsl:apply-templates select='exsl:node-set($data)/*' 
                         mode='format'/>
  </xsl:template>
  <xsl:template mode='format'
                match='*'>
    <xsl:copy>
      <xsl:apply-templates mode='format'/>
    </xsl:copy>
  </xsl:template>
  <xsl:template mode='format'
                match='text()'>
    <xsl:value-of select='normalize-space(.)'/>
  </xsl:template>
  <xsl:template mode='format'
                match='br'>
    <xsl:text>^^^</xsl:text>
  </xsl:template>
  <xsl:template mode='format'
                match='ul/li'>
    <xsl:text> * </xsl:text>
    <xsl:apply-templates mode='format'/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>
  <xsl:template mode='format'
                match='p'>
    <xsl:apply-templates mode='format'/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>  
  <xsl:template mode='format'
                match='p[@class="indent"]'>
    <!-- <xsl:text>    </xsl:text> -->
    <xsl:apply-templates mode='format'/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>
  <xsl:template mode='format'
                match='a|ul'>
    <xsl:apply-templates mode='format'/>
  </xsl:template>
</xsl:stylesheet>
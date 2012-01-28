<xsl:stylesheet 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    
    xmlns:acis="http://acis.openlib.org"
    exclude-result-prefixes='exsl xml acis html'
    version="1.0">

  <xsl:import href='page.xsl'/>

  <xsl:variable name='records' select='//records/list-item'/>

  <xsl:variable name='current-screen-id' select='"record-menu"'/>
  

  <xsl:template match='/'>

    <xsl:call-template name='user-account-page'>
      
      <xsl:with-param name='title'>Records menu</xsl:with-param>

      <xsl:with-param name='content'>

<h1>Records menu</h1>

<p><xsl:value-of select="count( $records )" /> records</p>

<xsl:choose>
  <xsl:when test='count( $records )'>

<table class='records sql'>
<tr>
<th>name</th>
<xsl:call-template name='record-actions-th'/>
</tr>

<xsl:for-each select='$records'>

<tr>
<td><xsl:value-of select='name'/></td>
<xsl:call-template name='record-actions-td'>
  <xsl:with-param name='rec' select='.'/>
</xsl:call-template>
</tr>
</xsl:for-each>

</table>
  </xsl:when>
</xsl:choose>


<p>Other options:</p>

<ul class='menu'>
  
  <li><a ref='settings' title='email, password, etc.' >account settings</a></li>

<!-- YYY <li><a ref='new-person' title='does not work'>create new personal record</a> 
  <xsl:text> </xsl:text>
  <i>(Does not yet work)</i>
  </li> -->

  <li><a ref='off'>log off</a></li>

  <li><a ref='unregister' >delete your account</a></li>

</ul>


      </xsl:with-param> <!-- /content -->
    </xsl:call-template>



  </xsl:template>


  <xsl:template name='record-actions-th'>
    <th colspan='7'>actions</th>
  </xsl:template>

  <xsl:template name='record-actions-td'>
    <xsl:param name='rec'/>
    <xsl:variable name='id'  select='$rec/id/text()'/>
    <xsl:variable name='sid' select='$rec/sid/text()'/>

    <td class='act'><a ref='@({$sid})menu'>enter</a></td>
    <td class='act'><a ref='@({$sid})/name'>name</a></td>
    <td class='act'><a ref='@({$sid})/contact'>contact</a></td>
    <td class='act'><a ref='@({$sid})/affiliations'>affiliations</a></td>
    <td class='act'><a ref='@({$sid})/research'>research</a></td>
    <td class='act'>
      <!--[if-config(citations-profile)]
       <a ref='@({$sid})/citations'>citations</a>
          [end-if]-->
    </td>
    <td class='act'> <a ref='@({$sid})profile-overview'>overview</a> </td>
  </xsl:template>


  <xsl:template name='record-brief-menu'>
    <xsl:param name='rec'/>

    <xsl:variable name='id'  select='$rec/id/text()'/>
    <xsl:variable name='sid' select='$rec/sid/text()'/>

    <!-- we absolutely assume record type="person" here -->
    <strong><span class='name'><xsl:value-of select='$rec/name'/></span></strong>:
    <a ref='@({$sid})profile-overview'>overview</a> | <a ref='@({$sid})menu'>menu</a>
    <br/>
    <small>
      <a ref='@({$sid})/name'>name</a> 
      | <a ref='@({$sid})/contact'>contact</a>
      | <a ref='@({$sid})/affiliations'>affiliations</a>
      | <a ref='@({$sid})/research'>research</a>
      <!--[if-config(citations-profile)]
        | <a ref='@({$sid})/citations'>citations</a>
          [end-if]-->
    </small>
  </xsl:template>



</xsl:stylesheet>
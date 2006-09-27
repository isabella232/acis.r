<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  version="1.0">  

  <xsl:template name='yes-no-choice' xmlns='http://x'> <!-- a form widget -->
    <xsl:param name='param-name'/>
    <xsl:param name='default'/>

<i><input type='radio' name='{$param-name}' id='{$param-name}-y' value='1'
>
<xsl:if test='$default = "yes"'>
  <xsl:attribute name='checked'/>
</xsl:if>
</input>
<xsl:text>&#160;</xsl:text>
<label for='{$param-name}-y'>Yes, please.</label><br/>
<input type='radio' name='{$param-name}' id='{$param-name}-n'
       value='0'
>
  <xsl:if test='$default = "no"'>
    <xsl:attribute name='checked'/>
  </xsl:if>
</input>
 
<xsl:text>&#160;</xsl:text>
<label for='{$param-name}-n'>No, thanks.</label>
</i>

  </xsl:template>


</xsl:stylesheet>
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:dp="http://www.datapower.com/extensions"
    xmlns:dpfunc="http://www.datapower.com/extensions/functions"
    xmlns:dpconfig="http://www.datapower.com/param/config"
    xmlns:func="http://exslt.org/functions"
    extension-element-prefixes="dp func"
    exclude-result-prefixes="dp dpfunc dpconfig func">    
    <xsl:template match="/"> 
        <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ws="http://ws.rcbj.com/">
            <soapenv:Header>
                <dp:set-http-request-header name="'API-OAUTH-METADATA-FOR-PAYLOAD'" value="'test'"/>
                <dp:set-http-request-header name="'API-OAUTH-METADATA-FOR-ACCESSTOKEN'" value="'test'"/>
            </soapenv:Header>
            <soapenv:Body>
                <ws:auth>
                    <return>accepted</return>
                </ws:auth>
            </soapenv:Body>
        </soapenv:Envelope>
    </xsl:template>
</xsl:stylesheet>

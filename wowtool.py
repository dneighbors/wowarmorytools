#!/usr/bin/env python

import httplib, urllib
import amara

def get_char_info(realm, char):
	"""Returns an XML tree <character/> element for char on realm"""
	headers = {"Accept": "application/xml, text/xml",
			   "User-Agent": "Firefox/2.0.0.1"} # Have to specify the firefox UA or we don't get XML.
	conn = httplib.HTTPConnection("eu.wowarmory.com:80")
	conn.request("GET", "/character-sheet.xml?%s" % urllib.urlencode({'r' : realm, 'n' : char}) , None, headers)
	response = conn.getresponse()
	body = response.read()
	doc = amara.parse(body)
	return doc.page.characterInfo.character

ct = get_char_info('hellfire', 'xoq')
print ct['name'] + " is a " + ct['class']
from hashlib import blake2b
import array
import functools
import html
import os
import posixpath
import urllib.parse
import xml.etree.ElementTree as ET
import zipfile

from termpub.urls import urlparse

class Epub:
    NS = {
        "cont": "urn:oasis:names:tc:opendocument:xmlns:container",
        "dc": "http://purl.org/dc/elements/1.1/",
        "opf": "http://www.idpf.org/2007/opf",
        "html": "http://www.w3.org/1999/xhtml",
        "xhtml": "http://www.w3.org/1999/xhtml",
        "daisy": "http://www.daisy.org/z3986/2005/ncx/",
    }

    def __init__(self, file):
        self.file = file
        self.zip = zipfile.ZipFile(file)

        container = ET.parse(self.zip.open("META-INF/container.xml"))
        self.rootfile = container.find(
            "cont:rootfiles/cont:rootfile", self.NS).get("full-path")

        if self.rootfile is None:
            raise Exception('Missing root file in epub!')

        self.root = ET.parse(self.zip.open(self.rootfile))

        self.title = self.find_text('.//dc:title', 'Unknown')
        self.language = self.find_text('.//dc:langauge')
        self.author = self.find_text('.//dc:creator', 'Unknown')

    def find_text(self, xpath, default=None):
        try:
            return html.unescape(
                self.root.find(xpath, self.NS).text);
        except AttributeError:
            return default

    def hash(self):
        checksums = array.array('L')
        for zo in self.zip.infolist():
            checksums.append(zo.CRC)
        h = blake2b()
        h.update(checksums)
        return h.hexdigest()

    @property
    @functools.lru_cache()
    def bodymatter(self):
        if self.nav_doc is not None:
            return self.nav_doc.bodymatter

        for tag in ("start", "text"):
            guide = self.root.find(
                f'.//opf:guide/opf:reference[@type="{tag}"]', self.NS)
            if guide is not None:
                href = guide.get('href')
                if href:
                    return urlparse(href, self.rootfile)

    @property
    @functools.lru_cache()
    def ncx_file(self):
        spine = self.root.find('.//opf:spine', self.NS)
        item = None
        if spine:
            ncx_id = spine.get('toc')
            if ncx_id:
                item = self.root.find(
                    f'.//opf:manifest/opf:item[@id="{ncx_id}"]', self.NS)
        if item is None:
            media = 'application/x-dtbncx+xml'
            item = self.root.find(
                f'.//opf:manifest/opf:item[@media-type="{media}"]', self.NS)
        if item is not None:
            file = item.get('href')
            if file:
                return urlparse(file, self.rootfile).path

    @property
    @functools.lru_cache()
    def mimetype(self,file):
        item = self.root.find(
            f'.//opf:manifest/opf:item[@href="{file}"]', self.NS)
        if item is not None:
            return item.get('media-type')

    @property
    @functools.lru_cache()
    def toc(self):
        source = None
        base_url = None
        if self.nav_doc:
            toc = self.nav_doc.toc
            if toc is not None:
                base_url = self.nav_doc.file
                source = toc
        if source is None:
            guide = self.root.find(
                './/opf:guide/opf:reference[@type="toc"]', self.NS)
            if guide is not None:
                href = guide.get('href')
                if href:
                    url = urlparse(href, self.rootfile)
                    base_url = url.path
                    source = ET.parse(self.zip.open(url.path)).getroot()
        if source is None:
            html = ''
            tree = ET.parse(self.zip.open(self.ncx_file))
            navmap = tree.find('.//daisy:navMap', self.NS)
            html = self.navmap_to_html(navmap)
            if html:
                source = ET.fromstring(
                    f'''
                        <!DOCTYPE html>
                        <html xmlns="http://www.w3.org/1999/xhtml">
                            <body>{html}</body>
                        </html>
                    '''
                )
                base_url = self.ncx_file

        if source:
            for a in source.findall('.//html:a[@href]', self.NS):
                url = urllib.parse.unquote(a.get('href'))
                url = urllib.parse.urljoin(base_url, url)
                a.set('href', url)
            return ET.tostring(source, encoding="unicode")

    def navmap_to_html(self, tree, html=''):
        points = tree.findall('./daisy:navPoint', self.NS)
        for point in points:
            html += '<ol>'
            content = point.find('./daisy:content', self.NS).get('src')
            label = point.find('./daisy:navLabel/daisy:text', self.NS).text
            html += f'<li><a href="{content}">{label}</a>'
            html += self.navmap_to_html(point)
            html += '</li></ol>'
        return html

    @property
    @functools.lru_cache()
    def nav_doc(self):
        item = self.root.find(
            './/opf:manifest/opf:item[@properties="nav"]', self.NS)
        if item is not None:
            href = item.get('href')
            if href:
                return NavDoc(self.zip, urlparse(href, self.rootfile).path)

    @property
    @functools.lru_cache()
    def chapters(self):
        manifest = {}
        for i in self.root.findall('opf:manifest/opf:item', self.NS):
            manifest[i.get('id')] = i

        chapters = []
        for i in self.root.findall('opf:spine/opf:itemref', self.NS):
            item = manifest[i.get('idref')]
            if item.get('media-type') == 'application/xhtml+xml':
                href = item.get('href')
                if href:
                    file = urlparse(href, self.rootfile).path
                    ## TODO check meta/charset for encoding
                    source = self.zip.open(file).read().decode("utf8")
                    chapters.append(Chapter(source, file))
        return chapters

class Chapter():
    def __init__(self, source, file):
        self.source = source
        self.file = file

class NavDoc:
    NS = {
        "epub": "http://www.idpf.org/2007/ops",
        "xhtml": "http://www.w3.org/1999/xhtml",
    }
    def __init__(self, zip, file):
        self.file = file
        self.dom = ET.parse(zip.open(file))

    @property
    @functools.lru_cache()
    def toc(self):
        return self.dom.find('.//xhtml:nav[@epub:type="toc"]', self.NS)

    @property
    @functools.lru_cache()
    def bodymatter(self):
        link = self.dom.find('.//xhtml:a[@epub:type="bodymatter"]', self.NS)
        if link is not None:
            href = link.get('href')
            if href:
                return urlparse(href, self.file)

    @property
    @functools.lru_cache()
    def page_list(self):
        pages = {}
        nav = self.dom.find('.//xhtml:nav[@epub:type="page-list"]', self.NS)
        if nav:
            for a in  nav.findall('.//xhtml:a[@href]', self.NS):
                url = urlparse(a.get('href'), self.file)
                pages[url] = a.text
        return pages

from hashlib import blake2b
import array
import html
import os
import posixpath
import xml.etree.ElementTree as ET
import zipfile

class Epub:
    NS = {
        "cont": "urn:oasis:names:tc:opendocument:xmlns:container",
        "dc": "http://purl.org/dc/elements/1.1/",
        "opf": "http://www.idpf.org/2007/opf",
    }


    def __init__(self, file):
        self.filename = file
        self.zip = zipfile.ZipFile(file)

        container = ET.parse(self.zip.open("META-INF/container.xml"))
        rootfile = container.find(
            "cont:rootfiles/cont:rootfile", self.NS).get("full-path")

        if rootfile is None:
            raise Exception('Missing root file in epub!')

        self.root = ET.parse(self.zip.open(rootfile))
        self.basedir = os.path.dirname(rootfile) + "/" \
            if os.path.dirname(rootfile) != "" else ""

        self.title = self.find_text('.//dc:title', 'Unknown')
        self.language = self.find_text('.//dc:langauge')
        self.author = self.find_text('.//dc:creator', 'Unknown')
        self.nav_doc = self.find_nav_doc()
        self.bodymatter = self.find_bodymatter()

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

    def normpath(self, path):
        return posixpath.normpath( self.basedir + path)

    def find_bodymatter(self):
        guide = self.root.find(
            './/opf:guide/opf:reference[@type="text"]', self.NS)
        if guide is not None:
            if href := guide.get('href'):
                return self.normpath(href)
        if self.nav_doc is not None:
            return self.nav_doc.bodymatter()

    def mimetype(self,file):
        item = self.root.find(
            f'.//opf:manifest/opf:item[@href="{file}"]', self.NS)
        if item is not None:
            return item.get('media-type')

    def find_toc(self):
        guide = self.root.find(
            './/opf:guide/opf:reference[@type="toc"]', self.NS)
        if guide is not None:
            if href := guide.get('href'):
                return self.normpath(href)

        if self.nav_doc is not None:
            if (toc := self.nav_doc.toc()) is not None:
                return toc

        item = self.root.find(
            './/opf:manifest/opf:item[@properties="nav"]', self.NS)
        if item is not None:
            if item.get('media-type') == 'application/xhtml+xml':
                if href := item.get('href'):
                    return self.normpath(href)

    def find_nav_doc(self):
        item = self.root.find(
            './/opf:manifest/opf:item[@properties="nav"]', self.NS)
        if item is not None:
            if href := item.get('href'):
                return NavDoc(self.zip, self.normpath(href))

    def chapters(self):
        manifest = {}
        for i in self.root.findall('opf:manifest/opf:item', self.NS):
            manifest[i.get('id')] = i

        chapters = []
        for i in self.root.findall('opf:spine/opf:itemref', self.NS):
            item = manifest[i.get('idref')]
            if item.get('media-type') == 'application/xhtml+xml':
                if href := item.get('href'):
                    file = self.normpath(href)
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
        self.dom = ET.parse(zip.open(file))
        self.basedir = os.path.dirname(file)
        if self.basedir:
            self.basedir += '/'

    def normpath(path):
        return posixpath.normpath( self.basedir + href)

    def toc(self):
        link = self.dom.find('.//xhtml:a[@epub:type="toc"]', self.NS)
        if link is not None:
            if href := link.get('href'):
                return self.normpath(href)

    def bodymatter(self):
        link = self.dom.find('.//xhtml:a[@epub:type="bodymatter"]', self.NS)
        if link is not None:
            if href := link.get('href'):
                return self.normpath(href)


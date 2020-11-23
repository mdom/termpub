from html.parser import HTMLParser
import re
import termpub.width as width
from termpub.urls import urlparse

class Renderer(HTMLParser):

    noshow = [
        'base', 'basefont', 'bgsound', 'meta', 'param', 'script', 'style'
    ]

    empty  = [
        'br', 'canvas', 'col', 'command', 'embed', 'frame', 'img', 'is',
        'index', 'keygen', 'link'
    ]

    inline = [
        'a', 'abbr', 'area', 'b', 'bdi', 'bdo', 'big', 'button', 'cite',
        'code', 'dfn', 'em', 'font', 'i', 'input', 'kbd', 'label', 'mark',
        'meter', 'nobr', 'progress', 'q', 'rp', 'rt', 'ruby', 's', 'samp',
        'small', 'span', 'strike', 'strong', 'sub', 'sup', 'time', 'tt', 'u',
        'var', 'wbr'
    ]

    block = [
        'address', 'applet', 'article', 'aside', 'audio', 'blockquote', 'body',
        'caption', 'center', 'colgroup', 'datalist', 'del', 'dir', 'div', 'dd',
        'details', 'dl', 'dt', 'fieldset', 'figcaption', 'figure', 'footer',
        'form', 'frameset', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head',
        'header', 'hgroup', 'hr', 'html', 'iframe', 'ins', 'legend', 'li',
        'listing', 'map', 'marquee', 'menu', 'nav', 'noembed', 'noframes',
        'noscript', 'object', 'ol', 'optgroup', 'option','p', 'pre', 'select',
        'section', 'source', 'summary', 'table', 'tbody', 'td', 'tfoot', 'th',
        'thead', 'title', 'tr', 'track', 'ul', 'video'
    ]

    def __init__(self, width=80, dic=None, base_url=None):
        self.width = width
        self.dic = dic
        self.base_url = base_url
        super().__init__()

    def render(self, html):
        self.chunks = []
        self.lines = []
        self.pending_ids = []
        self.locations = []
        self.id_positions = {}
        self.in_body = 0
        self.hanging_indent = 0
        self.indent = 0

        self.feed(html)

        while self.lines and self.lines[-1] == '':
            del self.lines[-1]

        locations = [urlparse(x, self.base_url) for x in self.locations]

        return self.lines, self.id_positions, locations

    ## TODO code and pre
    ## TODO lists

    def fill_text(self):
        if not self.chunks:
            return

        if self.hanging_indent:
            current_line_length = self.indent - 2
            current_line = ' ' * (self.indent -  2)
        else:
            current_line_length = self.indent 
            current_line = ' ' * self.indent

        ## TODO zero width space? no break?
        word_seperator = re.compile(r'(\s+)')

        chunks = []
        for x in self.chunks:
            if isinstance(x, tuple):
                self.pending_ids.append(x[0])
                continue
            for y in word_seperator.split(x):
                chunks.append(y)

        ## TODO word too long for line?
        for chunk in chunks:


            chunk.replace('\n','')
            chunk = re.sub(r'\s+', ' ', chunk)

            chunk_length = width.width(chunk)

            if current_line_length + chunk_length > self.width:

                if self.dic:
                    remaining = self.width - current_line_length
                    for pair in self.dic.iterate(chunk):
                        if width.width(pair[0]) + 1 <= remaining:
                            current_line += pair[0] + '-'
                            chunk = pair[1]
                            break

                self.add_new_line(current_line)
                current_line_length = self.indent
                current_line = ' ' * self.indent

            if word_seperator.match(chunk) and current_line_length == self.indent:
                continue


            if chunk_length < 0:
                raise Exception('indent negative')

            current_line += chunk
            current_line_length += chunk_length

        self.add_new_line(current_line)

        self.chunks = []

    def add_new_line(self, line):
        if not re.match(r'^\s*$', line):
            for id in self.pending_ids:
                self.id_positions[id] = len(self.lines)
            self.pending_ids = []
            self.lines.append( line.rstrip() )

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'body':
            self.in_body = 1
            return
        if not self.in_body:
            return


        if tag in self.block and self.chunks:
            self.fill_text()
            if tag in self.block and self.lines and self.lines[-1] != '':
                self.lines.append('')

        if 'id' in attrs:
            ## TODO Why ,1???
            self.chunks.append((attrs['id'], 1))

        m = re.match(r'h(\d)', tag)
        if m:
            self.chunks.append(('=' * int(m.group(1))) + ' ');

        elif tag == 'img':
            alt = attrs['alt'] or ''
            src = attrs['src']
            if src:
                self.locations.append(src)
                num = len(self.locations)
            self.chunks.append('![{}][{}]'.format(num,alt))

        elif tag == 'a':
            if 'href' in attrs:
                href = attrs['href']
                self.locations.append(href)
                num = len(self.locations)
                self.chunks.append('[{}]'.format(num))

        elif tag == 'br':
           self.fill_text()

        elif tag == 'blockquote':
            self.indent += 2

        elif tag == 'li':
            self.chunks.append('* ')
            self.indent += 2
            self.hanging_indent = 1

        elif tag == 'pre':
            self.fill_text()

    def handle_endtag(self, tag):
        if tag == 'pre':
            for chunk in self.chunks:
                for line in chunk.splitlines():
                    self.lines.append(line)
            self.chunks = []
        elif tag in self.block:
            self.fill_text()
        if tag in self.block and self.lines and self.lines[-1] != '':
            self.lines.append('')

        ## Remove indentation after text is wrapped
        if tag == 'li':
            self.indent -= 2
            self.hanging_indent = 0
        elif tag == 'blockquote':
            self.indent -= 2

    def handle_data(self, data):
        if not self.in_body:
            return
        self.chunks.append(data);

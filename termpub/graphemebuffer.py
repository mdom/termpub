import termpub.width as width
import unicodedata

class Buffer():

    def __init__(self, init=""):
        self.graphemes = []
        self.index = 0
        if init:
            self.add(init)

    def add(self, chunk):
        """Add chunk to string at current index."""
        for c in chunk:
            if unicodedata.combining(c):
                self.graphemes[self.index - 1] += c
            else:
                self.graphemes.insert(self.index, c)
                self.index += 1

    def replace(self, start, end, chunk):
        self.graphemes[start:end] = chunk
        self.index = start + width.width(chunk)

    def move_to_start(self):
        self.index = 0

    def move_to_end(self):
        self.index = len(self.graphemes)

    def move_left(self, n=1):
        if self.index - n >= 0:
            self.index -= n

    def move_right(self, n=1):
        if self.index + n <= len(self.graphemes):
            self.index += n

    def current_grapheme(self):
        return self.graphemes[self.index - 1]

    def delete_forward(self):
        if self.index < len(self.graphemes):
            del self.graphemes[self.index]

    def delete_backward(self):
        if self.index != 0:
            del self.graphemes[self.index - 1]
            self.index -= 1

    def delete_to_end(self):
        del self.graphemes[self.index:]

    def to_string(self):
        return ''.join(self.graphemes)

    def slice(self, width):
        offset = int( self.index / width) * width
        return ''.join(self.graphemes[offset:offset+width]), self.index - offset

    def clear(self):
        self.index = 0
        self.graphemes = []

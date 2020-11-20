import builtins
import unicodedata

def width(chunk):
    ## TODO use wcwidth or pyicu to compute visual length if those
    ## modules are available
    chars = [ c for c in chunk if not unicodedata.combining(c) ]
    return builtins.len(chars)

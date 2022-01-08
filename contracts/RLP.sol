library RLP { /**
    For a single byte whose value is in the [0x00, 0x7f] range, that byte is its own 
    RLP encoding. Otherwise, if a string is 0-55 bytes long, the RLP encoding consists of a 
    single byte with value 0x80 plus the length of the string followed by the string. The range 
    of the first byte is thus [0x80, 0xb7]. If a string is more than 55 bytes long, the RLP 
    encoding consists of a single byte with value 0xb7 plus the length in bytes of the length of 
    the string in binary form, followed by the length of the string, followed by the string. For 
    example, a length-1024 string would be encoded as \xb9\x04\x00 followed by the string. The 
    range of the first byte is thus [0xb8, 0xbf]. If the total payload of a list (i.e. the 
    combined length of all its items being RLP encoded) is 0-55 bytes long, the RLP encoding 
    consists of a single byte with value 0xc0 plus the length of the list followed by the 
    concatenation of the RLP encodings of the items. The range of the first byte is thus [0xc0, 
    0xf7]. If the total payload of a list is more than 55 bytes long, the RLP encoding consists 
    of a single byte with value 0xf7 plus the length in bytes of the length of the payload in 
    binary form, followed by the length of the payload, followed by the concatenation of the RLP 
    encodings of the items. The range of the first byte is thus [0xf8, 0xff]. */

    function encode() {}
}

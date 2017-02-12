import "lib/codec" =~ [=> composeCodec :DeepFrozen]
import "lib/codec/percent" =~ [=> PercentEncoding :DeepFrozen]
import "lib/codec/utf8" =~ [=> UTF8 :DeepFrozen]
import "unittest" =~ [=> unittest]

exports (parse_qsl, quote, unquote, makeParsedURL)

def UTF8Percent :DeepFrozen := composeCodec(PercentEncoding, UTF8)


def quote(specimen :Str) as DeepFrozen:
    "url quote a thing"
    return UTF8Percent.encode(specimen, null)

def unquote(specimen :Bytes) as DeepFrozen:
    "url unquote a thing"
    return UTF8Percent.decode(specimen, null)

def parse_qsl(qs :Str, keep_blank_values :Bool) :List[Pair[Str, Str]] as DeepFrozen:
    ""
    var pairs := [].diverge()
    for s1 in (qs.split("&")):
        for s2 in (s1.split(";")):
            pairs.push(s2)

    var r := [].diverge()
    for name_value in (pairs):
        if (name_value.isEmpty()):
            continue
        def nv := name_value.split("=")
        if (nv.size() != 2):
            throw(b`Bad query field $name_value`)
        if ((nv[1].size() > 0) || (keep_blank_values)):
            def name := unquote(UTF8.encode(nv[0].replace("+", " "), null))
            def value := unquote(UTF8.encode(nv[1].replace("+", " "), null))
            r.push([name, value])

    return r

def parse_qs(qs :Str, keep_blank_values :Bool) :Map[Str, List[Str]] as DeepFrozen:
    ""
    def m := [].asMap().diverge()
    def qsl_parsed := parse_qsl(qs, keep_blank_values)
    for key => value in (qsl_parsed):
        if (m.getKeys().contains(key)):
            m[key].append(value)
        else:
            m[key] := [value]
    return m

def _splitnetloc(url :Str, start :NullOk[Int]) as DeepFrozen:
    var _start := start
    if (_start == null):
        _start := 0

    var delim := url.size()
    for c in ("/?#".asList()):
        def wdelim := url.indexOf(c)
        if (wdelim >= 0):
            if (wdelim <= delim):
                delim := wdelim

    return [url.slice(_start, delim), url.slice(delim)]


def parseURL(url :Str) as DeepFrozen:
    var _url := url
    var _scheme := ""
    var _netloc := ""
    var _query := ""
    var _fragment := ""

    # SCHEME #
    def scheme_idx := _url.indexOf("://")
    if (scheme_idx > 0):
        _scheme := _url.slice(0, scheme_idx).toLowerCase()
        _url := _url.slice(scheme_idx + 1)

    # NETLOC #
    if (_url.slice(0, 2) == "//"):
        def [nl, rest] := _splitnetloc(_url.slice(2), 0)
        _netloc := nl
        _url := rest
        # IPv6 validity check
        def _not_closed := _netloc.contains("[") && !_netloc.contains("]")
        def _not_opened := _netloc.contains("]") && !_netloc.contains("[")
        if (_not_closed || _not_opened):
            throw(b`Invalid IPv6 address: $_netloc`)

    # FRAGMENT #
    if (_url.contains("#")):
        def frag_split := _url.split("#")
        if (frag_split.size() == 2):
            _url := frag_split[0]
            _fragment := frag_split[1]
        else:
            throw(b`Only one octothorp (#) allowed in an URL`)

    # QUERY #
    if (_url.contains("?")):
        def query_split := _url.split("?")
        if (query_split.size() == 2):
            _url := query_split[0]
            _query := query_split[1]
        else:
            throw(b`Only one ? allowed in an URL`)

    return [
        "scheme" => _scheme,
        "netloc" => _netloc,
        "path" => _url,
        "query" => _query,
        "fragment" => _fragment,
    ]

def makeParsedURL(url :Str) as DeepFrozen:
    var parsed := parseURL(url)

    return object URL:
        to scheme():
            return parsed["scheme"]
        to netloc():
            return parsed["netloc"]
        to path():
            return parsed["path"]
        to query():
            return parsed["query"]
        to queryAsMap():
            return parse_qs(parsed["query"])
        to fragment():
            return parsed["fragment"]
        to realm():
            "scheme + netloc := realm used by OAuth"
            var _url := ""
            if (parsed["scheme"].size() > 0):
                _url += parsed["scheme"] + ":"
            _url += "//"
            if (parsed["netloc"].size() > 0):
                _url += parsed["netloc"]
            return _url
        to asMap():
            return parsed
        to asString():
            var _url := ""
            if (parsed["scheme"].size() > 0):
                _url += parsed["scheme"] + ":"
            _url += "//"
            if (parsed["netloc"].size() > 0):
                _url += parsed["netloc"]
            if (parsed["path"].size() > 0):
                _url += "/" + parsed["path"]
            if (parsed["query"].size() > 0):
                _url += "?" + parsed["query"]
            if (parsed["fragment"].size() > 0):
                _url += "#" + parsed["fragment"]
            return _url


# TESTS #

def test_parseQSL(assert):
    def encoded := "a%20thing=a%20value"
    def res := [].asMap().diverge()
    res["a thing"] := "a value"
    assert.equal(parse_qsl(encoded, true), res)

unittest([
    test_parseQSL,
])

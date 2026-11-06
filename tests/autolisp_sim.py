#!/usr/bin/env python3
"""
Minimal AutoLISP simülatörü - REBAR .lsp dosyalarını AutoCAD olmadan test etmek için.

- AutoLISP sözdizimini okur (string, yorum, dotted pair, quote).
- Dinamik kapsam (dynamic scope), tek ad alanı, büyük/küçük harf duyarsız semboller.
- Tamsayı bölmesi ( (/ 5 2) = 2 ) gibi AutoLISP davranışlarını taklit eder.
- AutoLISP'te OLMAYAN bir fonksiyon çağrılırsa (let, dotimes ...) hata verir.
- entmake / tblsearch / getXXX / vla-* gibi AutoCAD fonksiyonlarını taklit eder,
  oluşturulan nesneleri kaydeder ve temel geçerlilik kontrolleri yapar.
"""
import math
import fnmatch
import os
import re
import sys


class LispError(Exception):
    pass


class LispExit(Exception):
    pass


class Sym:
    __slots__ = ("name",)
    _table = {}

    def __new__(cls, name):
        name = name.upper()
        s = cls._table.get(name)
        if s is None:
            s = object.__new__(cls)
            s.name = name
            cls._table[name] = s
        return s

    def __repr__(self):
        return self.name


class Pair:
    __slots__ = ("car", "cdr")

    def __init__(self, car, cdr):
        self.car, self.cdr = car, cdr

    def __repr__(self):
        return f"({lisp_repr(self.car)} . {lisp_repr(self.cdr)})"

    def __eq__(self, o):
        return isinstance(o, Pair) and lisp_equal(self.car, o.car) and lisp_equal(self.cdr, o.cdr)


T = Sym("T")
QUOTE = Sym("QUOTE")


def lisp_repr(v):
    if v is None:
        return "nil"
    if isinstance(v, list):
        return "(" + " ".join(lisp_repr(x) for x in v) + ")"
    if isinstance(v, str):
        return '"' + v + '"'
    return repr(v)


def lisp_equal(a, b, fuzz=0.0):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(a - b) <= fuzz
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(lisp_equal(x, y, fuzz) for x, y in zip(a, b))
    if isinstance(a, Pair) and isinstance(b, Pair):
        return lisp_equal(a.car, b.car, fuzz) and lisp_equal(a.cdr, b.cdr, fuzz)
    return a == b


# ---------------------------------------------------------------- reader
TOKEN_RE = re.compile(r"""\s+|;\|.*?\|;|;[^\n]*|"(?:\\.|[^"\\])*"|[()']|[^\s()';"]+""", re.S)
NUM_RE = re.compile(r"^[+-]?(\d+\.?\d*([eE][+-]?\d+)?|\.\d+([eE][+-]?\d+)?)$")


def unescape(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            out.append({"n": "\n", "t": "\t", "r": "\r", "e": "\x1b", "\\": "\\", '"': '"'}.get(n, "\\" + n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def tokenize(src):
    pos, toks = 0, []
    while pos < len(src):
        m = TOKEN_RE.match(src, pos)
        if not m:
            raise LispError(f"okunamayan karakter: {src[pos:pos+20]!r}")
        t = m.group(0)
        line = src.count("\n", 0, pos) + 1
        pos = m.end()
        if t.isspace() or t.startswith(";"):
            continue
        toks.append((t, line))
    return toks


def parse(src, fname="?"):
    toks = tokenize(src)
    i = 0

    def read():
        nonlocal i
        if i >= len(toks):
            raise LispError(f"{fname}: beklenmeyen dosya sonu (kapanmamış parantez)")
        t, line = toks[i]
        i += 1
        if t == "(":
            items, dotted = [], None
            while True:
                if i >= len(toks):
                    raise LispError(f"{fname}: satır {line} ile açılan parantez kapanmamış")
                if toks[i][0] == ")":
                    i += 1
                    break
                if toks[i][0] == ".":
                    i += 1
                    dotted = read()
                    if toks[i][0] != ")":
                        raise LispError(f"{fname}: hatalı dotted pair satır {line}")
                    i += 1
                    break
                items.append(read())
            if dotted is not None:
                if len(items) != 1:
                    raise LispError(f"{fname}: çok elemanlı dotted liste desteklenmiyor satır {line}")
                return Pair(items[0], dotted)
            return items if items else None
        if t == ")":
            raise LispError(f"{fname}: fazla kapanan parantez satır {line}")
        if t == "'":
            return [QUOTE, read()]
        if t.startswith('"'):
            return unescape(t[1:-1])
        if NUM_RE.match(t):
            if re.match(r"^[+-]?\d+$", t):
                return int(t)
            return float(t)
        return Sym(t)

    forms = []
    while i < len(toks):
        forms.append(read())
    return forms


# ---------------------------------------------------------------- interpreter
class Lambda:
    def __init__(self, name, params, local_vars, body):
        self.name, self.params, self.locals, self.body = name, params, local_vars, body


class CatchErr:
    def __init__(self, msg):
        self.msg = msg


class VlaObj:
    def __init__(self, kind, **kw):
        self.kind = kind
        self.__dict__.update(kw)

    def __repr__(self):
        return f"#<VLA {self.kind}>"


def truthy(v):
    return v is not None and v != []


def as_list(v):
    if v is None:
        return []
    if isinstance(v, list):
        return v
    raise LispError(f"bad argument type: listp {lisp_repr(v)}")


def num(v, fn):
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        raise LispError(f"bad argument type: numberp: {lisp_repr(v)} ({fn})")
    return v


def car(v):
    if isinstance(v, Pair):
        return v.car
    l = as_list(v)
    return l[0] if l else None


def cdr(v):
    if isinstance(v, Pair):
        return v.cdr
    l = as_list(v)
    return l[1:] or None


class Interp:
    def __init__(self, base_dir, inputs=None):
        self.base_dir = base_dir
        self.g = {}
        self.inputs = inputs if callable(inputs) else list(inputs or [])
        self.prompts = []
        self.output = []
        self.alerts = []
        self.entities = []
        self.dims = []
        self.tables = {"LAYER": {"0": {}}, "LTYPE": {"CONTINUOUS": {}}, "STYLE": {"STANDARD": {}}}
        self.vars = {"CMDECHO": 1, "TILEMODE": 1, "CVPORT": 2, "UCSXDIR": [1.0, 0.0, 0.0],
                     "CLAYER": "0", "TEXTSTYLE": "Standard"}
        self.initget_kw = None
        self.initget_bits = 0
        self.undo_depth = 0
        self.depth = 0
        self.g["PI"] = math.pi
        self.g["T"] = T
        self.g["*ERROR*"] = None
        self._install_builtins()

    # ------------- environment
    def get(self, s):
        if s is T:
            return T
        return self.g.get(s.name)

    def set(self, s, v):
        if s is T or s.name in ("PI", "NIL"):
            raise LispError(f"attempt to set protected symbol {s.name}")
        self.g[s.name] = v

    # ------------- eval
    def eval(self, x):
        if isinstance(x, Sym):
            if x.name == "NIL":
                return None
            return self.get(x)
        if not isinstance(x, list):
            return x  # number, string, None, Pair
        head = x[0]
        if isinstance(head, Sym):
            sf = SPECIAL.get(head.name)
            if sf:
                return sf(self, x)
            fn = self.get(head)
            if fn is None:
                raise LispError(f"no function definition: {head.name}")
        else:
            fn = self.eval(head)
        args = [self.eval(a) for a in x[1:]]
        return self.call(fn, args, head)

    def call(self, fn, args, name="?"):
        if isinstance(fn, Sym):
            f2 = self.get(fn)
            if f2 is None:
                raise LispError(f"no function definition: {fn.name}")
            fn = f2
        if isinstance(fn, list) and fn and fn[0] == Sym("LAMBDA"):
            params, local_vars = parse_params(fn[1], "lambda")
            fn = Lambda("lambda", params, local_vars, fn[2:])
        if callable(fn) and not isinstance(fn, Lambda):
            return fn(*args)
        if isinstance(fn, Lambda):
            if len(args) != len(fn.params):
                raise LispError(f"too {'few' if len(args) < len(fn.params) else 'many'} arguments: {fn.name}")
            names = [p.name for p in fn.params] + [l.name for l in fn.locals]
            saved = {n: self.g.get(n, _UNBOUND) for n in names}
            try:
                for n in names:
                    self.g[n] = None
                for p, a in zip(fn.params, args):
                    self.g[p.name] = a
                self.depth += 1
                if self.depth > 400:
                    raise LispError("stack overflow")
                res = None
                for form in fn.body:
                    res = self.eval(form)
                return res
            finally:
                self.depth -= 1
                for n, v in saved.items():
                    if v is _UNBOUND:
                        self.g.pop(n, None)
                    else:
                        self.g[n] = v
        raise LispError(f"bad function: {lisp_repr(fn)} ({name})")

    def run_forms(self, forms):
        res = None
        for f in forms:
            res = self.eval(f)
        return res

    def load_file(self, path):
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        return self.run_forms(parse(src, os.path.basename(path)))

    def command(self, name):
        """AutoCAD komut satırından komut çalıştırır (*error* davranışı dahil)."""
        fn = self.get(Sym("C:" + name))
        if fn is None:
            raise LispError(f"Bilinmeyen komut {name}")
        try:
            return self.call(fn, [], "C:" + name)
        except (LispError, LispExit) as e:
            handler = self.get(Sym("*ERROR*"))
            msg = str(e) if isinstance(e, LispError) else "quit / exit abort"
            if handler:
                self.call(handler, [msg])
            raise

    # ------------- input
    def next_input(self, prompt):
        self.prompts.append(prompt)
        if callable(self.inputs):
            return self.inputs(prompt)
        if not self.inputs:
            raise LispError(f"test girdisi bitti; istem: {prompt!r}")
        return self.inputs.pop(0)

    def _install_builtins(self):
        B = {}
        it = self

        def reg(name):
            def deco(f):
                B[name.upper()] = f
                return f
            return deco

        # arithmetic
        def arith(op, fname):
            def f(*a):
                for x in a:
                    num(x, fname)
                if not a:
                    return 0
                r = a[0]
                if fname == "-" and len(a) == 1:
                    return -r
                if fname == "/" and len(a) == 1:
                    return r
                for x in a[1:]:
                    if fname == "/":
                        if x == 0:
                            raise LispError("divide by zero")
                        if isinstance(r, int) and isinstance(x, int):
                            q = abs(r) // abs(x)
                            r = q if (r >= 0) == (x >= 0) else -q
                        else:
                            r = r / x
                    else:
                        r = op(r, x)
                return r
            return f

        B["+"] = arith(lambda a, b: a + b, "+")
        B["-"] = arith(lambda a, b: a - b, "-")
        B["*"] = lambda *a: math.prod([num(x, "*") for x in a]) if a else 0
        B["/"] = arith(None, "/")
        B["1+"] = lambda x: num(x, "1+") + 1
        B["1-"] = lambda x: num(x, "1-") - 1
        B["ABS"] = lambda x: abs(num(x, "abs"))
        B["MIN"] = lambda *a: self._minmax(min, a)
        B["MAX"] = lambda *a: self._minmax(max, a)
        B["FIX"] = lambda x: int(num(x, "fix"))
        B["FLOAT"] = lambda x: float(num(x, "float"))
        B["SQRT"] = lambda x: math.sqrt(num(x, "sqrt"))
        B["SIN"] = lambda x: math.sin(num(x, "sin"))
        B["COS"] = lambda x: math.cos(num(x, "cos"))
        B["ATAN"] = lambda y, x=None: math.atan(y) if x is None else math.atan2(y, x)
        B["EXPT"] = lambda a, b: a ** b if not (isinstance(a, int) and isinstance(b, int)) else int(a ** b)
        B["REM"] = lambda a, b: math.fmod(a, b) if isinstance(a, float) or isinstance(b, float) else int(math.fmod(a, b))
        B["="] = lambda *a: T if all(lisp_equal(a[0], x) for x in a[1:]) else None
        B["/="] = lambda a, b: T if not lisp_equal(a, b) else None
        B["<"] = lambda *a: T if all(num(a[i], "<") < num(a[i + 1], "<") for i in range(len(a) - 1)) else None
        B[">"] = lambda *a: T if all(num(a[i], ">") > num(a[i + 1], ">") for i in range(len(a) - 1)) else None
        B["<="] = lambda *a: T if all(num(a[i], "<=") <= num(a[i + 1], "<=") for i in range(len(a) - 1)) else None
        B[">="] = lambda *a: T if all(num(a[i], ">=") >= num(a[i + 1], ">=") for i in range(len(a) - 1)) else None
        B["EQUAL"] = lambda a, b, fz=0.0: T if lisp_equal(a, b, fz) else None
        B["EQ"] = lambda a, b: T if (a is b or (isinstance(a, (int, float, str)) and a == b)) else None
        B["NOT"] = lambda x: None if truthy(x) else T
        B["NULL"] = B["NOT"]
        B["MINUSP"] = lambda x: T if num(x, "minusp") < 0 else None
        B["ZEROP"] = lambda x: T if num(x, "zerop") == 0 else None
        B["NUMBERP"] = lambda x: T if isinstance(x, (int, float)) else None
        B["LISTP"] = lambda x: T if (x is None or isinstance(x, (list, Pair))) else None
        B["BOUNDP"] = lambda s: T if self.get(s) is not None else None
        B["TYPE"] = lambda x: Sym({int: "INT", float: "REAL", str: "STR", list: "LIST"}.get(type(x), "SYM")) if x is not None else None

        # lists
        B["CAR"] = car
        B["CDR"] = cdr
        B["CADR"] = lambda x: car(cdr(x))
        B["CDDR"] = lambda x: cdr(cdr(x))
        B["CAAR"] = lambda x: car(car(x))
        B["CDAR"] = lambda x: cdr(car(x))
        B["CADDR"] = lambda x: car(cdr(cdr(x)))
        B["LIST"] = lambda *a: list(a) or None
        B["CONS"] = lambda a, b: [a] + b if isinstance(b, list) else ([a] if b is None else Pair(a, b))
        B["APPEND"] = lambda *a: sum((list(as_list(x)) for x in a), []) or None
        B["REVERSE"] = lambda x: list(reversed(as_list(x))) or None
        B["LENGTH"] = lambda x: len(as_list(x))
        B["NTH"] = lambda n, l: as_list(l)[n] if 0 <= n < len(as_list(l)) else None
        B["LAST"] = lambda l: as_list(l)[-1] if as_list(l) else None
        B["MEMBER"] = lambda x, l: next((as_list(l)[i:] for i, y in enumerate(as_list(l)) if lisp_equal(x, y)), None)
        B["ASSOC"] = lambda k, l: next((e for e in as_list(l) if lisp_equal(car(e), k)), None)
        B["VL-POSITION"] = lambda x, l: next((i for i, y in enumerate(as_list(l)) if lisp_equal(x, y)), None)

        def mapcar(fn, *lists):
            ls = [as_list(l) for l in lists]
            n = min(len(l) for l in ls) if ls else 0
            return [self.call(fn, [l[i] for l in ls], "mapcar") for i in range(n)] or None
        B["MAPCAR"] = mapcar
        B["APPLY"] = lambda fn, args: self.call(fn, as_list(args), "apply")

        # strings
        def strcat(*a):
            for x in a:
                if not isinstance(x, str):
                    raise LispError(f"bad argument type: stringp {lisp_repr(x)}")
            return "".join(a)
        B["STRCAT"] = strcat

        def itoa(x):
            if not isinstance(x, int):
                raise LispError(f"bad argument type: fixnump: {lisp_repr(x)}")
            return str(x)
        B["ITOA"] = itoa
        B["ATOI"] = lambda s: int(re.match(r"\s*[+-]?\d*", s).group(0).strip() or 0) if re.match(r"\s*[+-]?\d", s) else 0
        B["ATOF"] = lambda s: float(re.match(r"\s*[+-]?(\d+\.?\d*|\.\d+)", s).group(0)) if re.match(r"\s*[+-]?(\d|\.\d)", s) else 0.0

        def rtos(x, mode=2, prec=4):
            num(x, "rtos")
            if mode != 2:
                raise LispError("simülatör yalnız rtos mode 2 destekler")
            return f"{x:.{prec}f}"
        B["RTOS"] = rtos

        def substr(s, start, n=None):
            if not isinstance(s, str):
                raise LispError("bad argument type: stringp")
            return s[start - 1:] if n is None else s[start - 1:start - 1 + n]
        B["SUBSTR"] = substr
        B["STRLEN"] = lambda *a: sum(len(strcat(x)) for x in a)
        B["STRCASE"] = lambda s, lower=None: strcat(s).lower() if truthy(lower) else strcat(s).upper()

        def wcmatch(s, pat):
            return T if any(fnmatch.fnmatchcase(strcat(s), p) for p in strcat(pat).split(",")) else None
        B["WCMATCH"] = wcmatch

        # io
        def princ(x=None, f=None):
            self.output.append(x if isinstance(x, str) else ("" if x is None else lisp_repr(x)))
            return x
        B["PRINC"] = princ
        B["PRIN1"] = princ
        B["PRINT"] = princ
        B["PROMPT"] = princ
        B["TERPRI"] = lambda: None

        def alert(msg):
            self.alerts.append(strcat(msg))
            return None
        B["ALERT"] = alert

        # user input
        def initget(*a):
            bits, kw = 0, None
            for x in a:
                if isinstance(x, int):
                    bits = x
                elif isinstance(x, str):
                    kw = x
            self.initget_bits, self.initget_kw = bits, kw
            return None
        B["INITGET"] = initget

        def take(prompt):
            bits, kw = self.initget_bits, self.initget_kw
            self.initget_bits, self.initget_kw = 0, None
            v = self.next_input(prompt)
            return v, bits, kw

        def check_num(v, bits, prompt):
            if v is None:
                if bits & 1:
                    raise LispError(f"initget 1: Enter kabul edilmez ama test Enter verdi: {prompt}")
                return None
            if (bits & 2) and v == 0:
                raise LispError(f"initget 2 ihlali: {prompt}")
            if (bits & 4) and v < 0:
                raise LispError(f"initget 4 ihlali: {prompt}")
            return v

        def getreal(prompt=""):
            v, bits, kw = take(prompt)
            if isinstance(v, str):
                return self._match_kw(v, kw, prompt)
            if v is not None:
                v = float(num(v, "getreal"))
            return check_num(v, bits, prompt)
        B["GETREAL"] = getreal

        def getint(prompt=""):
            v, bits, kw = take(prompt)
            if isinstance(v, str):
                return self._match_kw(v, kw, prompt)
            if v is not None and not isinstance(v, int):
                raise LispError(f"getint tam sayı bekler: {prompt}")
            return check_num(v, bits, prompt)
        B["GETINT"] = getint

        def getkword(prompt=""):
            v, bits, kw = take(prompt)
            if v is None:
                if bits & 1:
                    raise LispError(f"initget 1 + Enter: {prompt}")
                return None
            return self._match_kw(v, kw, prompt)
        B["GETKWORD"] = getkword

        def getpoint(a=None, b=None):
            prompt = a if isinstance(a, str) else (b or "")
            v, bits, kw = take(prompt)
            if v is None:
                return None
            if not (isinstance(v, list) and len(v) in (2, 3)):
                raise LispError(f"getpoint nokta bekler: {prompt}")
            v = [float(x) for x in v]
            return v if len(v) == 3 else v + [0.0]
        B["GETPOINT"] = getpoint
        B["GETCORNER"] = getpoint
        B["GETDIST"] = lambda a=None, b=None: take(a if isinstance(a, str) else b)[0]
        B["GETSTRING"] = lambda a=None, b=None: take(b if isinstance(b, str) else a)[0] or ""

        # geometry
        B["DISTANCE"] = lambda p1, p2: math.dist(p1[:2] if len(p1) == 2 or len(p2) == 2 else p1, p2[:2] if len(p1) == 2 or len(p2) == 2 else p2)

        def angle(p1, p2):
            a = math.atan2(p2[1] - p1[1], p2[0] - p1[0])
            return a % (2 * math.pi)
        B["ANGLE"] = angle
        B["POLAR"] = lambda p, a, d: [p[0] + d * math.cos(a), p[1] + d * math.sin(a)] + ([p[2]] if len(p) > 2 else [])
        B["TRANS"] = lambda p, f, t, d=None: list(p)

        # system
        B["GETVAR"] = lambda n: self.vars.get(strcat(n).upper())

        def setvar(n, v):
            self.vars[strcat(n).upper()] = v
            return v
        B["SETVAR"] = setvar

        def tblsearch(table, name, nxt=None):
            t = self.tables.get(strcat(table).upper(), {})
            return [Pair(0, table.upper()), Pair(2, name)] if strcat(name).upper() in t else None
        B["TBLSEARCH"] = tblsearch

        def findfile(name):
            p = os.path.join(self.base_dir, name)
            return p if os.path.exists(p) else None
        B["FINDFILE"] = findfile

        def load(path, onfail=None):
            p = path if os.path.isabs(path) else os.path.join(self.base_dir, path)
            if not os.path.exists(p):
                raise LispError(f"LOAD failed: {path}")
            return self.load_file(p)
        B["LOAD"] = load

        def exit_():
            raise LispExit()
        B["EXIT"] = exit_
        B["QUIT"] = exit_

        B["ENTMAKE"] = self._entmake
        B["ENTLAST"] = lambda: len(self.entities) if self.entities else None

        # ActiveX stubs
        acad = VlaObj("Application")
        doc = VlaObj("Document")
        ms = VlaObj("ModelSpace")
        ps = VlaObj("PaperSpace")
        lts = VlaObj("Linetypes")
        B["VL-LOAD-COM"] = lambda: None
        B["VLAX-GET-ACAD-OBJECT"] = lambda: acad
        B["VLA-GET-ACTIVEDOCUMENT"] = lambda a: doc

        def need(o, kind, fn):
            if not (isinstance(o, VlaObj) and o.kind == kind):
                raise LispError(f"{fn}: {kind} bekleniyor, gelen {o!r}")
        B["VLA-GET-MODELSPACE"] = lambda d: (need(d, "Document", "vla-get-ModelSpace"), ms)[1]
        B["VLA-GET-PAPERSPACE"] = lambda d: (need(d, "Document", "vla-get-PaperSpace"), ps)[1]
        B["VLA-GET-LINETYPES"] = lambda d: (need(d, "Document", "vla-get-Linetypes"), lts)[1]

        def start_undo(d):
            need(d, "Document", "StartUndoMark")
            self.undo_depth += 1
        B["VLA-STARTUNDOMARK"] = start_undo

        def end_undo(d):
            need(d, "Document", "EndUndoMark")
            self.undo_depth -= 1
        B["VLA-ENDUNDOMARK"] = end_undo

        def lt_load(coll, name, f):
            need(coll, "Linetypes", "vla-Load")
            if strcat(f).lower() not in ("acad.lin", "acadiso.lin"):
                raise LispError("bilinmeyen lin dosyası")
            if strcat(name).upper() in ("DASHED", "HIDDEN", "CENTER", "CENTER2"):
                self.tables["LTYPE"][name.upper()] = {}
            return None
        B["VLA-LOAD"] = lt_load
        B["VLAX-3D-POINT"] = lambda *p: VlaObj("Point", xyz=[float(x) for x in (p[0] if len(p) == 1 else p)])

        def add_dim(space, p1, p2, pt):
            need(space, space.kind if space in (ms, ps) else "ModelSpace", "AddDimAligned")
            for p in (p1, p2, pt):
                need(p, "Point", "AddDimAligned")
            d = VlaObj("Dimension", p1=p1.xyz, p2=p2.xyz, pt=pt.xyz, layer="0", scale=1.0)
            self.dims.append(d)
            return d
        B["VLA-ADDDIMALIGNED"] = add_dim

        def put_layer(o, name):
            need(o, "Dimension", "put-Layer")
            if strcat(name).upper() not in self.tables["LAYER"]:
                raise LispError(f"katman yok: {name}")
            o.layer = name
        B["VLA-PUT-LAYER"] = put_layer

        def put_scale(o, s):
            need(o, "Dimension", "put-ScaleFactor")
            if num(s, "ScaleFactor") <= 0:
                raise LispError("ScaleFactor > 0 olmalı")
            o.scale = s
        B["VLA-PUT-SCALEFACTOR"] = put_scale

        def catch_apply(fn, args):
            try:
                return self.call(fn, as_list(args), "vl-catch-all-apply")
            except LispError as e:
                return CatchErr(str(e))
        B["VL-CATCH-ALL-APPLY"] = catch_apply
        B["VL-CATCH-ALL-ERROR-P"] = lambda x: T if isinstance(x, CatchErr) else None
        B["VL-CATCH-ALL-ERROR-MESSAGE"] = lambda x: x.msg

        self.builtins = set(B)
        self.g.update(B)

    def _minmax(self, f, a):
        for x in a:
            num(x, "min/max")
        r = f(a)
        return float(r) if any(isinstance(x, float) for x in a) else r

    def _match_kw(self, v, kw, prompt):
        if kw is None:
            raise LispError(f"anahtar kelime girildi ama initget yok: {prompt}")
        for k in kw.split():
            req = "".join(ch for ch in k if ch.isupper() or ch.isdigit()) or k
            if v.upper() == k.upper() or v.upper() == req.upper():
                return k
        raise LispError(f"geçersiz anahtar kelime {v!r} (izinli: {kw}) istem: {prompt}")

    def _entmake(self, data):
        items = as_list(data)
        codes = []
        for e in items:
            if not isinstance(e, Pair) and not (isinstance(e, list) and e):
                raise LispError(f"entmake: geçersiz grup {lisp_repr(e)}")
            if isinstance(e, Pair):
                codes.append((e.car, e.cdr))
            else:
                codes.append((e[0], e[1:]))
        d = {}
        for c, v in codes:
            d.setdefault(c, []).append(v)
        kind = d.get(0, [None])[0]
        if kind == "LAYER":
            name = d[2][0]
            lt = d.get(6, ["Continuous"])[0]
            if lt.upper() not in self.tables["LTYPE"]:
                raise LispError(f"entmake LAYER: çizgi tipi yüklü değil {lt}")
            self.tables["LAYER"][name.upper()] = {"color": d.get(62, [7])[0], "ltype": lt}
            return data
        if kind not in ("LINE", "LWPOLYLINE", "CIRCLE", "TEXT"):
            raise LispError(f"entmake: desteklenmeyen tip {kind}")
        layer = d.get(8, [None])[0]
        if not isinstance(layer, str):
            raise LispError(f"entmake {kind}: katman yok")
        if layer.upper() not in self.tables["LAYER"]:
            raise LispError(f"entmake {kind}: tanımsız katman {layer} (testte önce oluşturulmalı)")
        if 62 in d and not (isinstance(d[62][0], int) and 0 <= d[62][0] <= 256):
            raise LispError(f"entmake: geçersiz renk {d[62][0]}")

        def pt(v, n):
            if not (isinstance(v, list) and len(v) == n and all(isinstance(x, (int, float)) for x in v)):
                raise LispError(f"entmake {kind}: geçersiz nokta {lisp_repr(v)} ({n}B bekleniyor)")
            return v
        if kind == "LINE":
            pt(d[10][0], 3); pt(d[11][0], 3)
        elif kind == "CIRCLE":
            pt(d[10][0], 3)
            if not d[40][0] > 0:
                raise LispError("entmake CIRCLE: yarıçap <= 0")
        elif kind == "TEXT":
            pt(d[10][0], 3)
            if not isinstance(d[1][0], str):
                raise LispError("entmake TEXT: metin string olmalı")
            if not d[40][0] > 0:
                raise LispError("entmake TEXT: yükseklik <= 0")
        elif kind == "LWPOLYLINE":
            verts = d.get(10, [])
            for v in verts:
                pt(v, 2)
            if d[90][0] != len(verts):
                raise LispError("entmake LWPOLYLINE: 90 kodu köşe sayısıyla uyuşmuyor")
        self.entities.append({"type": kind, "layer": layer, "data": d})
        return data


_UNBOUND = object()


# ---------------------------------------------------------------- special forms
def sf_quote(it, x):
    return x[1]


def sf_setq(it, x):
    args = x[1:]
    if len(args) % 2:
        raise LispError("setq: tek sayıda argüman")
    v = None
    for i in range(0, len(args), 2):
        if not isinstance(args[i], Sym):
            raise LispError(f"setq: sembol bekleniyor {lisp_repr(args[i])}")
        v = it.eval(args[i + 1])
        it.set(args[i], v)
    return v


def parse_params(lst, fname):
    params, local_vars, seen_slash = [], [], False
    for p in as_list(lst):
        if p == Sym("/"):
            seen_slash = True
            continue
        if not isinstance(p, Sym):
            raise LispError(f"{fname}: geçersiz parametre {lisp_repr(p)}")
        (local_vars if seen_slash else params).append(p)
    return params, local_vars


def sf_defun(it, x):
    name = x[1]
    params, local_vars = parse_params(x[2], name.name)
    fn = Lambda(name.name, params, local_vars, x[3:])
    it.set(name, fn)
    return name


def sf_lambda(it, x):
    params, local_vars = parse_params(x[1], "lambda")
    return Lambda("lambda", params, local_vars, x[2:])


def sf_function(it, x):
    return it.eval(x[1]) if isinstance(x[1], list) and x[1] and x[1][0] == Sym("LAMBDA") else x[1]


def sf_if(it, x):
    if len(x) > 4:
        raise LispError("if: çok fazla argüman")
    if truthy(it.eval(x[1])):
        return it.eval(x[2])
    return it.eval(x[3]) if len(x) > 3 else None


def sf_cond(it, x):
    for clause in x[1:]:
        clause = as_list(clause)
        v = it.eval(clause[0])
        if truthy(v):
            for f in clause[1:]:
                v = it.eval(f)
            return v
    return None


def sf_progn(it, x):
    return it.run_forms(x[1:])


def sf_while(it, x):
    v, n = None, 0
    while truthy(it.eval(x[1])):
        v = it.run_forms(x[2:])
        n += 1
        if n > 100000:
            raise LispError("while: sonsuz döngü?")
    return v


def sf_repeat(it, x):
    n = it.eval(x[1])
    if not isinstance(n, int):
        raise LispError(f"repeat: tam sayı bekler, gelen {lisp_repr(n)}")
    v = None
    for _ in range(n):
        v = it.run_forms(x[2:])
    return v


def sf_foreach(it, x):
    var = x[1]
    lst = as_list(it.eval(x[2]))
    saved = it.g.get(var.name, _UNBOUND)
    v = None
    try:
        for e in lst:
            it.g[var.name] = e
            v = it.run_forms(x[3:])
    finally:
        if saved is _UNBOUND:
            it.g.pop(var.name, None)
        else:
            it.g[var.name] = saved
    return v


def sf_and(it, x):
    for f in x[1:]:
        if not truthy(it.eval(f)):
            return None
    return T


def sf_or(it, x):
    for f in x[1:]:
        if truthy(it.eval(f)):
            return T
    return None


SPECIAL = {"QUOTE": sf_quote, "SETQ": sf_setq, "DEFUN": sf_defun, "LAMBDA": sf_lambda,
           "FUNCTION": sf_function, "IF": sf_if, "COND": sf_cond, "PROGN": sf_progn,
           "WHILE": sf_while, "REPEAT": sf_repeat, "FOREACH": sf_foreach, "AND": sf_and, "OR": sf_or}


# ---------------------------------------------------------------- static checks
def static_check(path, builtins):
    """Parantez dengesi, defun parametre/yerel değişken çakışmaları ve gölgelenen yerleşik fonksiyonlar."""
    problems = []
    with open(path, encoding="utf-8") as fh:
        src = fh.read()
    forms = parse(src, os.path.basename(path))
    protected = {"T", "PI", "NIL"}

    def walk(f):
        if isinstance(f, list) and f:
            if f[0] in (Sym("DEFUN"), Sym("LAMBDA")):
                plist = f[2] if f[0] == Sym("DEFUN") else f[1]
                fname = f[1].name if f[0] == Sym("DEFUN") else "lambda"
                names = [p.name for p in as_list(plist) if isinstance(p, Sym) and p.name != "/"]
                dup = {n for n in names if names.count(n) > 1}
                if dup:
                    problems.append(f"{fname}: aynı isimli (büyük/küçük harf duyarsız) değişkenler {sorted(dup)}")
                for n in names:
                    if n in protected:
                        problems.append(f"{fname}: korumalı sembol değişken olarak kullanılmış: {n}")
                    elif n in builtins:
                        problems.append(f"{fname}: yerleşik fonksiyon gölgeleniyor: {n}")
                if f[0] == Sym("DEFUN") and f[1].name in builtins:
                    problems.append(f"yerleşik fonksiyon yeniden tanımlanıyor: {f[1].name}")
            for e in f:
                walk(e)
    for f in forms:
        walk(f)
    return problems


if __name__ == "__main__":
    base = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    it = Interp(base)
    bad = 0
    for fn in sorted(os.listdir(base)):
        if fn.lower().endswith(".lsp"):
            try:
                probs = static_check(os.path.join(base, fn), it.builtins)
            except LispError as e:
                probs = [str(e)]
            print(f"{fn}: {'OK' if not probs else ''}")
            for p in probs:
                print("   -", p)
            bad += len(probs)
    sys.exit(1 if bad else 0)

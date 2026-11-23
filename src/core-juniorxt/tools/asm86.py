"""A small 8086 assembler for the Winchester coupler's option ROM (tools/hdrom.py) and the manual disk (manual-disk/tools/build.py).

    from asm86 import assemble
    code = assemble('''
        org 100h
        mov ah,9
        mov dx,msg
        int 21h
        mov ax,4C00h
        int 21h
    msg: db 'Hello', 13, 10, '$'
    ''')

NASM-like syntax, the subset the checks and the option ROM use: labels (name:), ';' comments, org, db, dw,
times N db X, NAME equ EXPR, and the instructions below. Numbers are decimal, 0x1F or 1Fh, or a 'c'
character; an expression is numbers and names joined by +, - and * (* binds first), and $ is the address of
the instruction. A memory operand is [seg:base+index+disp] (a bare [label] or [1234h] is a direct address),
with byte or word in front when the register does not say. jcc, loop and jcxz are short jumps; jmp and call
are near (jmp short for a short one), through a register or a word in memory (jmp [cs:bx+table]), or far:
jmp far SEG:OFF, jmp far [mem], call far [mem].

    mov add or adc sbb and sub xor cmp test inc dec neg not mul imul div idiv xchg lea lds les push pop
    shl shr sar rol ror rcl rcr in out int jmp call ret retf (with a count too) iret jcc loop loope loopne
    jcxz cli sti cld std clc stc cmc nop hlt pushf popf lahf sahf lodsb lodsw stosb stosw movsb movsw cmpsb
    cmpsw scasb scasw rep repe repne cbw cwd xlat

Instruction encodings are from Intel's 8086 Family User's Manual; MezinXT's own code.
"""

from __future__ import annotations

import re

REG16 = {"ax": 0, "cx": 1, "dx": 2, "bx": 3, "sp": 4, "bp": 5, "si": 6, "di": 7}
REG8 = {"al": 0, "cl": 1, "dl": 2, "bl": 3, "ah": 4, "ch": 5, "dh": 6, "bh": 7}
SREG = {"es": 0, "cs": 1, "ss": 2, "ds": 3}
SEG_PREFIX = {"es": 0x26, "cs": 0x2E, "ss": 0x36, "ds": 0x3E}
ALU = {"add": 0, "or": 1, "adc": 2, "sbb": 3, "and": 4, "sub": 5, "xor": 6, "cmp": 7}
SHIFT = {"rol": 0, "ror": 1, "rcl": 2, "rcr": 3, "shl": 4, "sal": 4, "shr": 5, "sar": 7}
UNARY = {"not": 2, "neg": 3, "mul": 4, "imul": 5, "div": 6, "idiv": 7}
JCC = {"jo": 0x70, "jno": 0x71, "jb": 0x72, "jc": 0x72, "jnae": 0x72, "jnb": 0x73, "jae": 0x73, "jnc": 0x73,
       "jz": 0x74, "je": 0x74, "jnz": 0x75, "jne": 0x75, "jbe": 0x76, "jna": 0x76, "ja": 0x77, "jnbe": 0x77,
       "js": 0x78, "jns": 0x79, "jp": 0x7A, "jnp": 0x7B, "jl": 0x7C, "jnge": 0x7C, "jge": 0x7D, "jnl": 0x7D,
       "jle": 0x7E, "jng": 0x7E, "jg": 0x7F, "jnle": 0x7F, "loop": 0xE2, "loope": 0xE1, "loopz": 0xE1,
       "loopne": 0xE0, "loopnz": 0xE0, "jcxz": 0xE3}
SIMPLE = {"cli": 0xFA, "sti": 0xFB, "cld": 0xFC, "std": 0xFD, "clc": 0xF8, "stc": 0xF9, "nop": 0x90, "hlt": 0xF4,
          "pushf": 0x9C, "popf": 0x9D, "ret": 0xC3, "retf": 0xCB, "iret": 0xCF, "lodsb": 0xAC, "lodsw": 0xAD,
          "stosb": 0xAA, "stosw": 0xAB, "movsb": 0xA4, "movsw": 0xA5, "cmpsb": 0xA6, "scasb": 0xAE, "cbw": 0x98,
          "cwd": 0x99, "xlat": 0xD7, "rep": 0xF3, "repe": 0xF3, "repne": 0xF2, "cmc": 0xF5, "lahf": 0x9F,
          "sahf": 0x9E, "cmpsw": 0xA7, "scasw": 0xAF}


TOKENS = re.compile(r"'.'|\$|[A-Za-z_.][A-Za-z_0-9.]*|[0-9][0-9A-Za-z]*|[+*-]")


class AsmError(Exception):
    pass


class Operand:
    """kind: 'r8', 'r16', 'sreg', 'imm', 'mem'. For a memory operand: modrm (the rm field and mod 0..2, or
    direct), disp (an expression text), prefix (a segment override byte or None) and size (8, 16 or None)."""

    def __init__(self, kind, **kw):
        self.kind = kind
        self.__dict__.update(kw)


def split_operands(text: str) -> list[str]:
    out, depth, quote, cur = [], 0, None, ""
    for ch in text:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
            cur += ch
        elif ch == "[":
            depth += 1
            cur += ch
        elif ch == "]":
            depth -= 1
            cur += ch
        elif ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


class Assembler:
    def __init__(self):
        self.labels: dict[str, int] = {}
        self.origin = 0x100

    # --- expressions -------------------------------------------------------------------------
    def value(self, expr: str, pc: int, final: bool) -> int:
        """The value of an expression; labels are 0 in the first pass."""
        expr = expr.strip()

        def number(tok: str) -> int:
            if len(tok) == 3 and tok[0] == tok[2] == "'":
                return ord(tok[1])
            if tok == "$":
                return pc
            if re.fullmatch(r"0[xX][0-9A-Fa-f]+", tok):
                return int(tok, 16)
            if re.fullmatch(r"[0-9][0-9A-Fa-f]*[hH]", tok):
                return int(tok[:-1], 16)
            if re.fullmatch(r"[0-9]+", tok):
                return int(tok)
            if tok in self.labels:
                return self.labels[tok]
            if not final:
                return 0
            raise AsmError(f"unknown name {tok!r}")

        tokens = TOKENS.findall(expr)
        if "".join(tokens).replace(" ", "") != expr.replace(" ", ""):
            raise AsmError(f"bad expression {expr!r}")
        # terms joined by + and -, each a product of numbers
        total, sign, term, pending_mul = 0, 1, None, False
        for tok in tokens:
            if tok in "+-":
                if term is not None:
                    total += sign * term
                    term = None
                sign = 1 if tok == "+" else -1
                pending_mul = False
            elif tok == "*":
                if term is None:
                    raise AsmError(f"bad expression {expr!r}")
                pending_mul = True
            else:
                n = number(tok)
                term = term * n if pending_mul and term is not None else n
                pending_mul = False
        if pending_mul:
            raise AsmError(f"bad expression {expr!r}")
        if term is not None:
            total += sign * term
        return total

    def has_label(self, expr: str) -> bool:
        """The expression names a label (its value is not known in the first pass)."""
        return any(re.fullmatch(r"[A-Za-z_.][A-Za-z_0-9.]*", tok) for tok in TOKENS.findall(expr))

    # --- operands ----------------------------------------------------------------------------
    def operand(self, text: str) -> Operand:
        t = text.strip()
        low = t.lower()
        size = None
        m = re.match(r"(byte|word)\s+(.*)", low)
        if m:
            size = 8 if m.group(1) == "byte" else 16
            t = t[len(m.group(1)):].strip()
            low = m.group(2)
        if low in REG8:
            return Operand("r8", reg=REG8[low])
        if low in REG16:
            return Operand("r16", reg=REG16[low])
        if low in SREG:
            return Operand("sreg", reg=SREG[low])
        if t.startswith("["):
            if not t.endswith("]"):
                raise AsmError(f"bad memory operand {text!r}")
            inner = t[1:-1].strip()
            prefix = None
            m = re.match(r"(es|cs|ss|ds)\s*:\s*(.*)", inner, re.I)
            if m:
                prefix = SEG_PREFIX[m.group(1).lower()]
                inner = m.group(2)
            regs, disp = [], ""
            for part in re.findall(r"[+-]?\s*[^+-]+", inner):
                p = part.replace(" ", "")
                name = p.lstrip("+-").lower()
                if name in REG16:
                    if p.startswith("-"):
                        raise AsmError(f"cannot subtract a register in {text!r}")
                    regs.append(name)
                else:
                    disp += ("" if p[0] in "+-" else "+") + p
            return Operand("mem", regs=sorted(regs), disp=disp.lstrip("+") if disp else "", prefix=prefix, size=size)
        return Operand("imm", expr=t)

    RM = {("bx", "si"): 0, ("bx", "di"): 1, ("bp", "si"): 2, ("bp", "di"): 3, ("si",): 4, ("di",): 5, ("bp",): 6, ("bx",): 7}

    def modrm(self, reg: int, op: Operand, pc: int, final: bool) -> bytes:
        """The ModRM byte (and displacement) with `reg` in the reg field and `op` (a register or memory) as r/m."""
        if op.kind in ("r8", "r16"):
            return bytes([0xC0 | reg << 3 | op.reg])
        if op.kind != "mem":
            raise AsmError("a register or memory operand is needed")
        key = tuple(op.regs)
        if key == ():
            addr = self.value(op.disp, pc, final) & 0xFFFF
            return bytes([reg << 3 | 6, addr & 255, addr >> 8])
        if key not in self.RM:
            raise AsmError(f"no such addressing mode: {'+'.join(key)}")
        rm = self.RM[key]
        if op.disp:
            d = self.value(op.disp, pc, final)
            if self.has_label(op.disp) or not -128 <= d <= 127:
                return bytes([0x80 | reg << 3 | rm, d & 255, (d >> 8) & 255])
            return bytes([0x40 | reg << 3 | rm, d & 255])
        if rm == 6:
            return bytes([0x40 | reg << 3 | rm, 0])
        return bytes([reg << 3 | rm])

    # --- one instruction -----------------------------------------------------------------------
    def encode(self, mnemonic: str, args: list[str], pc: int, final: bool) -> bytes:
        m = mnemonic.lower()
        if m in SIMPLE and not args:
            return bytes([SIMPLE[m]])
        if m in ("ret", "retf") and args:
            n = self.value(args[0], pc, final)
            return bytes([0xC2 if m == "ret" else 0xCA, n & 255, (n >> 8) & 255])
        ops = [self.operand(a) for a in args] if m not in ("jmp", "call") else []
        v = lambda e: self.value(e, pc, final)

        def sz(*os):
            for o in os:
                if o.kind == "r8":
                    return 8
                if o.kind == "r16":
                    return 16
                if o.kind == "mem" and o.size:
                    return o.size
            raise AsmError(f"{mnemonic} {', '.join(args)}: byte or word is needed")

        def with_prefix(*os):
            for o in os:
                if o.kind == "mem" and o.prefix:
                    return bytes([o.prefix])
            return b""

        def imm(value, size):
            if size == 8:
                if not -128 <= value <= 255:
                    raise AsmError(f"{value} does not fit a byte")
                return bytes([value & 255])
            return bytes([value & 255, (value >> 8) & 255])

        if m in JCC:
            target = v(args[0])
            rel = target - (pc + 2)
            if final and not -128 <= rel <= 127:
                raise AsmError(f"{m} {args[0]}: the target is {rel} bytes away")
            return bytes([JCC[m], rel & 255])
        if m in ("jmp", "call"):
            if args[0].lower().startswith("short "):
                target = v(args[0][6:])
                rel = target - (pc + 2)
                if final and not -128 <= rel <= 127:
                    raise AsmError(f"jmp short {args[0][6:]}: the target is {rel} bytes away")
                return bytes([0xEB, rel & 255])
            text = args[0].strip()
            if text.lower().startswith("far "):
                rest = text[4:].strip()
                if rest.startswith("["):
                    o = self.operand("word " + rest)
                    return with_prefix(o) + bytes([0xFF]) + self.modrm(5 if m == "jmp" else 3, o, pc, final)
                seg, _, off = rest.partition(":")
                if not off:
                    raise AsmError(f"{m} far needs SEG:OFF or a memory operand")
                return bytes([0xEA if m == "jmp" else 0x9A]) + imm(v(off), 16) + imm(v(seg), 16)
            o = self.operand(text)
            if o.kind in ("r16", "mem"):
                return with_prefix(o) + bytes([0xFF]) + self.modrm(4 if m == "jmp" else 2, o, pc, final)
            target = v(text)
            rel = (target - (pc + 3)) & 0xFFFF
            return bytes([0xE9 if m == "jmp" else 0xE8, rel & 255, rel >> 8])
        if m == "int":
            return bytes([0xCD, v(args[0]) & 255])
        if m == "mov":
            d, s = ops
            if d.kind == "sreg":
                return bytes([0x8E]) + self.modrm(d.reg, s, pc, final)
            if s.kind == "sreg":
                return with_prefix(d) + bytes([0x8C]) + self.modrm(s.reg, d, pc, final)
            if s.kind == "imm":
                if d.kind in ("r8", "r16"):
                    return bytes([(0xB0 if d.kind == "r8" else 0xB8) + d.reg]) + imm(v(s.expr), 8 if d.kind == "r8" else 16)
                size = sz(d)
                return with_prefix(d) + bytes([0xC6 if size == 8 else 0xC7]) + self.modrm(0, d, pc, final) + imm(v(s.expr), size)
            if s.kind in ("r8", "r16"):
                return with_prefix(d) + bytes([0x88 if s.kind == "r8" else 0x89]) + self.modrm(s.reg, d, pc, final)
            if d.kind in ("r8", "r16"):
                return with_prefix(s) + bytes([0x8A if d.kind == "r8" else 0x8B]) + self.modrm(d.reg, s, pc, final)
            raise AsmError("mov of memory to memory")
        if m in ALU:
            n = ALU[m]
            d, s = ops
            if s.kind == "imm":
                size = sz(d)
                value = v(s.expr)
                if size == 8:
                    return with_prefix(d) + bytes([0x80]) + self.modrm(n, d, pc, final) + imm(value, 8)
                if not self.has_label(s.expr) and -128 <= value <= 127:
                    return with_prefix(d) + bytes([0x83]) + self.modrm(n, d, pc, final) + imm(value, 8)
                return with_prefix(d) + bytes([0x81]) + self.modrm(n, d, pc, final) + imm(value, 16)
            if s.kind in ("r8", "r16"):
                return with_prefix(d) + bytes([n * 8 + (0 if s.kind == "r8" else 1)]) + self.modrm(s.reg, d, pc, final)
            return with_prefix(s) + bytes([n * 8 + (2 if d.kind == "r8" else 3)]) + self.modrm(d.reg, s, pc, final)
        if m == "test":
            d, s = ops
            if s.kind == "imm":
                size = sz(d)
                return with_prefix(d) + bytes([0xF6 if size == 8 else 0xF7]) + self.modrm(0, d, pc, final) + imm(v(s.expr), size)
            return with_prefix(d) + bytes([0x84 if s.kind == "r8" else 0x85]) + self.modrm(s.reg, d, pc, final)
        if m in ("inc", "dec"):
            d, = ops
            n = 0 if m == "inc" else 1
            if d.kind == "r16":
                return bytes([(0x40 if m == "inc" else 0x48) + d.reg])
            return with_prefix(d) + bytes([0xFE if sz(d) == 8 else 0xFF]) + self.modrm(n, d, pc, final)
        if m in UNARY:
            d, = ops
            return with_prefix(d) + bytes([0xF6 if sz(d) == 8 else 0xF7]) + self.modrm(UNARY[m], d, pc, final)
        if m in SHIFT:
            d, c = ops
            size = sz(d)
            if c.kind == "r8" and c.reg == 1:
                return with_prefix(d) + bytes([0xD2 if size == 8 else 0xD3]) + self.modrm(SHIFT[m], d, pc, final)
            if c.kind == "imm" and v(c.expr) == 1:
                return with_prefix(d) + bytes([0xD0 if size == 8 else 0xD1]) + self.modrm(SHIFT[m], d, pc, final)
            raise AsmError(f"{m}: the count is 1 or cl")
        if m == "xchg":
            a, b = ops
            if a.kind == "r16" and b.kind == "r16" and 0 in (a.reg, b.reg):
                return bytes([0x90 + (b.reg if a.reg == 0 else a.reg)])
            if b.kind == "mem":
                a, b = b, a
            return with_prefix(a) + bytes([0x86 if b.kind == "r8" else 0x87]) + self.modrm(b.reg, a, pc, final)
        if m in ("lea", "lds", "les"):
            d, s = ops
            if d.kind != "r16" or s.kind != "mem":
                raise AsmError(f"{m} needs a word register and a memory operand")
            return with_prefix(s) + bytes([{"lea": 0x8D, "lds": 0xC5, "les": 0xC4}[m]]) + self.modrm(d.reg, s, pc, final)
        if m == "push":
            d, = ops
            if d.kind == "sreg":
                return bytes([0x06 | d.reg << 3])
            if d.kind == "mem":
                return with_prefix(d) + bytes([0xFF]) + self.modrm(6, d, pc, final)
            if d.kind != "r16":
                raise AsmError("push takes a word register, a segment register or memory")
            return bytes([0x50 + d.reg])
        if m == "pop":
            d, = ops
            if d.kind == "sreg":
                return bytes([0x07 | d.reg << 3])
            if d.kind == "mem":
                return with_prefix(d) + bytes([0x8F]) + self.modrm(0, d, pc, final)
            if d.kind != "r16":
                raise AsmError("pop takes a word register, a segment register or memory")
            return bytes([0x58 + d.reg])
        if m in ("in", "out"):
            if m == "in":
                d, s = ops
                wide = d.kind == "r16"
                if s.kind == "r16" and s.reg == 2:
                    return bytes([0xED if wide else 0xEC])
                return bytes([0xE5 if wide else 0xE4, v(s.expr) & 255])
            d, s = ops
            wide = s.kind == "r16"
            if d.kind == "r16" and d.reg == 2:
                return bytes([0xEF if wide else 0xEE])
            return bytes([0xE7 if wide else 0xE6, v(d.expr) & 255])
        raise AsmError(f"unknown instruction {mnemonic} {', '.join(args)}")

    # --- the program ---------------------------------------------------------------------------
    def data(self, directive: str, args: list[str], pc: int, final: bool) -> bytes:
        out = bytearray()
        if directive == "times":
            count = self.value(args[0].split()[0], pc, final)
            rest = " ".join(args).split(None, 1)[1]
            name, _, tail = rest.partition(" ")
            return self.data(name.lower(), split_operands(tail), pc, final) * count
        for a in args:
            if len(a) >= 2 and a[0] == a[-1] and a[0] in "'\"" and len(a) != 3:
                text = a[1:-1].encode("latin-1")
                out += text if directive == "db" else b"".join(bytes([c, 0]) for c in text)
            else:
                value = self.value(a, pc + len(out), final)
                out += bytes([value & 255]) if directive == "db" else bytes([value & 255, (value >> 8) & 255])
        return bytes(out)

    def parse(self, source: str):
        for raw in source.splitlines():
            line = raw
            quote = None
            for i, ch in enumerate(raw):
                if quote:
                    if ch == quote:
                        quote = None
                elif ch in "'\"":
                    quote = ch
                elif ch == ";":
                    line = raw[:i]
                    break
            line = line.strip()
            while True:
                m = re.match(r"([A-Za-z_.][A-Za-z_0-9.]*):\s*(.*)", line)
                if not m:
                    break
                yield ("label", m.group(1))
                line = m.group(2)
            if not line:
                continue
            m = re.match(r"([A-Za-z_.][A-Za-z_0-9.]*)\s+equ\s+(.+)", line, re.I)
            if m:
                yield ("equ", m.group(1), m.group(2).strip())
                continue
            word, _, rest = line.partition(" ")
            if word.lower() == "times":
                yield ("data", "times", [rest.strip()])
            elif word.lower() in ("db", "dw"):
                yield ("data", word.lower(), split_operands(rest))
            elif word.lower() == "org":
                yield ("org", rest.strip())
            else:
                # a prefix such as "rep stosb" is an instruction of its own
                head = word.lower()
                if head in ("rep", "repe", "repne") and rest.strip():
                    yield ("insn", head, [])
                    w2, _, r2 = rest.strip().partition(" ")
                    yield ("insn", w2, split_operands(r2))
                else:
                    yield ("insn", word, split_operands(rest))

    def assemble(self, source: str) -> bytes:
        """Passes until the addresses settle (a forward name can change a size), then the final one."""
        items = list(self.parse(source))
        for _ in range(8):
            before = dict(self.labels)
            self.run(items, False)
            if self.labels == before:
                break
        else:
            raise AsmError("the addresses do not settle")
        settled = dict(self.labels)
        out = self.run(items, True)
        if self.labels != settled:
            raise AsmError("the final pass moved an address")
        return out

    def run(self, items, final: bool) -> bytes:
        out = bytearray()
        pc = self.origin
        for item in items:
            if item[0] == "equ":
                self.labels[item[1]] = self.value(item[2], pc, final)
            elif item[0] == "label":
                self.labels[item[1]] = pc
            elif item[0] == "org":
                self.origin = pc = self.value(item[1], pc, True)
                if out:
                    raise AsmError("org after code")
            elif item[0] == "data":
                b = self.data(item[1], item[2], pc, final)
                out += b
                pc += len(b)
            else:
                b = self.encode(item[1], item[2], pc, final)
                out += b
                pc += len(b)
        return bytes(out)


def assemble(source: str) -> bytes:
    return Assembler().assemble(source)

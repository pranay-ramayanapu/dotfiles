"""
Dedupe Google Drive images against the phone folder (SHA-256), then copy
only the genuinely new ones into phone/non-duplicates/ (structure preserved).

  merge_gdrive.py plan   -> dry run, writes a plan, copies NOTHING
  merge_gdrive.py copy   -> executes the plan (safe to stop and re-run)
"""
import hashlib, json, os, shutil, stat, sys
from pathlib import Path

HOME   = Path.home()
GDRIVE = HOME / "Pictures/old pics"
PHONE  = HOME / "D-Drive/master-media"
DEST   = PHONE / "non-duplicates"
WORK   = HOME / ".cache/gdrive-merge"      # outside both trees
PLAN   = WORK / "plan.jsonl"
REPORT = WORK / "report.jsonl"

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()

def human(n):
    for u in ("B", "KiB", "MiB", "GiB", "TiB"):
        if n < 1024 or u == "TiB":
            return f"{n:.2f} {u}" if u != "B" else f"{n} B"
        n /= 1024

def walk(root, errors, skip=None):
    """Yield (path, size) for every regular file; record anything unreadable."""
    def onerr(e): errors.append((str(e.filename), f"walk error: {e}"))
    for dp, dns, fns in os.walk(root, onerror=onerr, followlinks=False):
        if skip is not None:
            dns[:] = [d for d in dns if os.path.join(dp, d) != str(skip)]
        for fn in fns:
            p = os.path.join(dp, fn)
            try:
                st = os.lstat(p)
            except OSError as e:
                errors.append((p, f"stat error: {e}")); continue
            if stat.S_ISREG(st.st_mode):
                yield p, st.st_size
            else:
                errors.append((p, "skipped: not a regular file (symlink/special)"))

def resolve_dest(dest, digest, size):
    """Return (path, already_present). Never returns a path holding different content."""
    cands = [dest]
    stem, suf = dest.stem, dest.suffix
    cands.append(dest.with_name(f"{stem}__{digest[:8]}{suf}"))
    n = 2
    while True:
        for c in cands:
            if not c.exists():
                return c, False
            try:
                if c.stat().st_size == size and sha256(c) == digest:
                    return c, True
            except OSError:
                pass
        cands = [dest.with_name(f"{stem}__{digest[:8]}_{n}{suf}")]
        n += 1

def plan():
    WORK.mkdir(parents=True, exist_ok=True)
    errors = []

    print("Scanning Google Drive...", file=sys.stderr)
    g_files = sorted(walk(GDRIVE, errors))
    g_sizes = {s for _, s in g_files}

    print("Scanning phone (excluding non-duplicates/)...", file=sys.stderr)
    p_files = list(walk(PHONE, errors, skip=DEST))
    # A file can only match if its size matches some Drive file's size,
    # so only hash those. Still a full SHA-256 content comparison.
    candidates = [(p, s) for p, s in p_files if s in g_sizes]
    print(f"Hashing {len(candidates)}/{len(p_files)} phone files with matching sizes...", file=sys.stderr)
    phone_hashes = set()
    for i, (p, _) in enumerate(candidates, 1):
        try: phone_hashes.add(sha256(p))
        except OSError as e: errors.append((p, f"read error: {e}"))
        if i % 500 == 0: print(f"  {i}/{len(candidates)}", file=sys.stderr)

    print(f"Hashing {len(g_files)} Drive files...", file=sys.stderr)
    in_phone = internal_dup = already = 0
    to_copy, report, seen = [], [], set()
    for i, (p, size) in enumerate(g_files, 1):
        rel = os.path.relpath(p, GDRIVE)
        try: d = sha256(p)
        except OSError as e:
            errors.append((p, f"read error: {e}")); continue
        if d in phone_hashes:
            in_phone += 1; status = "in_phone"
        elif d in seen:
            internal_dup += 1; status = "duplicate_within_gdrive"
        else:
            seen.add(d)
            dest, present = resolve_dest(DEST / rel, d, size)
            if present:
                already += 1; status = "already_copied"
            else:
                status = "to_copy"
                to_copy.append({"src_rel": rel, "dest_rel": os.path.relpath(dest, DEST),
                                "size": size, "sha256": d})
        report.append({"src_rel": rel, "status": status, "sha256": d})
        if i % 500 == 0: print(f"  {i}/{len(g_files)}", file=sys.stderr)

    # Make planned destinations unique among themselves (defensive)
    used = set()
    for e in to_copy:
        while e["dest_rel"] in used:
            e["dest_rel"] += f".{e['sha256'][:8]}"
        used.add(e["dest_rel"])

    with open(PLAN, "w") as f:
        for e in to_copy: f.write(json.dumps(e) + "\n")
    with open(REPORT, "w") as f:
        for e in report: f.write(json.dumps(e) + "\n")

    total = sum(e["size"] for e in to_copy)
    print("\n===== DRY RUN REPORT =====")
    print(f"Google Drive files scanned:            {len(g_files)}")
    print(f"  Already exist in phone (skipped):    {in_phone}")
    print(f"  Not in phone (genuinely new):        {len(g_files) - in_phone - len([1 for p,_ in g_files if False]) - sum(1 for e in errors if 'read error' in e[1] and e[0].startswith(str(GDRIVE)))}")
    print(f"    - duplicates of another Drive file:{internal_dup:>4}  (only one copy kept)")
    print(f"    - already copied in earlier run:   {already}")
    print(f"    - WILL BE COPIED:                  {len(to_copy)}")
    print(f"Total size to copy:                    {human(total)} ({total} bytes)")
    print(f"Errors / unreadable / skipped:         {len(errors)}")
    for p, msg in errors[:50]: print(f"    {p}: {msg}")
    if len(errors) > 50: print(f"    ... and {len(errors)-50} more")
    st = shutil.disk_usage(PHONE.parent)
    print(f"Free space on target filesystem:       {human(st.free)}")
    print(f"\nPlan:   {PLAN}\nReport: {REPORT}  (per-file status)\nNothing was copied.")

def copy():
    if not PLAN.exists():
        sys.exit("No plan found. Run:  merge_gdrive.py plan")
    entries = [json.loads(l) for l in open(PLAN)]
    copied = skipped = 0
    errors = []
    for i, e in enumerate(entries, 1):
        src = GDRIVE / e["src_rel"]
        digest, size = e["sha256"], e["size"]
        try:
            dest, present = resolve_dest(DEST / e["dest_rel"], digest, size)
            if present:
                skipped += 1; continue
            dest.parent.mkdir(parents=True, exist_ok=True)
            part = dest.with_name(dest.name + ".part")
            shutil.copyfile(src, part)
            shutil.copystat(src, part)
            if sha256(part) != digest:
                part.unlink(missing_ok=True)
                errors.append((str(src), "hash mismatch after copy (source changed?)")); continue
            os.link(part, dest)      # fails if dest exists -> never overwrites
            os.unlink(part)
            copied += 1
        except FileExistsError:
            errors.append((str(src), "destination appeared during copy; left untouched"))
        except OSError as ex:
            errors.append((str(src), str(ex)))
        if i % 200 == 0: print(f"  {i}/{len(entries)}", file=sys.stderr)
    print(f"\nCopied: {copied}   Already present (skipped): {skipped}   Errors: {len(errors)}")
    for p, m in errors: print(f"  {p}: {m}")

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("plan", "copy"):
        sys.exit(__doc__)
    plan() if sys.argv[1] == "plan" else copy()

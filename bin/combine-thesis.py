#!/usr/bin/env python3
"""Assemble reagan-thesis-main-combined.tex from the per-chapter sources.

This reproduces the flattened single-file thesis by:
  1. Starting with reagan-thesis-main.tex
  2. Expanding every \\input{\\filenamebase.X}
  3. Stripping %% comments (full-line %% comments remove the line; inline
     %% comments truncate at the %% marker, preserving preceding chars)
  4. Collapsing runs of consecutive blank lines down to one
  5. Substituting \\bibliography{...} with the contents of the current
     reagan-thesis-main.bbl
  6. Dropping \\input{\\currfilebase.settings} (the \\filenamebase macro
     it defines is not needed once inputs are inlined)

Two variants:
  --variant root    (default) writes reagan-thesis-main-combined.tex
  --variant package writes package/reagan-thesis-main-combined.tex with
                    figure paths remapped to fig01..fig30 for arXiv upload

Before running, generate the .bbl once:
  pdflatex -draftmode reagan-thesis-main.tex
  bibtex reagan-thesis-main

Usage:
  python3 bin/combine-thesis.py [--variant root|package] [--check] [output]

With --check, compares against the committed target byte-for-byte and
exits 1 on any difference.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BASE = "reagan-thesis"
MAIN = REPO / f"{BASE}-main.tex"
COMBINED = REPO / f"{BASE}-main-combined.tex"
BBL = REPO / f"{BASE}-main.bbl"

# Figure-path remap for the arXiv package variant. The submitted sources
# reference figures by their original filenames under figures/ (or absolute
# paths for figures that never got copied into the repo); the arXiv upload
# renames them fig01_, fig02_, ... so the tarball is self-contained.
PACKAGE_FIGURE_REMAP = [
    ("figures/Energy-Balance-Model-Schematic.png", "fig01_Energy-Balance-Model-Schematic.pdf"),
    ("figures/Earth-System-Model-Schematic.png", "fig02_Earth-System-Model-Schematic.pdf"),
    ("figures/attractor-colored-by-innovation-prevPos3.pdf", "fig03_attractor-colored-by-innovation-prevPos3.pdf"),
    ("figures/DA-example03-labels.pdf", "fig04_DA-example03-labels.pdf"),
    ("figures/TLM-explanation.pdf", "fig05_TLM-explanation.pdf"),
    ("figures/TLM-verification003_noname.pdf", "fig06_TLM-verification003_noname.pdf"),
    ("figures/EnKF-histogram-analysis.pdf", "fig07_EnKF-histogram-analysis.pdf"),
    ("figures/EnKF_spaghetti.pdf", "fig08_EnKF_spaghetti.pdf"),
    ("figures/ott2004algorithmPic2.png", "fig09_ott2004algorithmPic2.pdf"),
    ("../2013-05data-assimilation/src/experiments/DATest/DA_test_noname010.pdf", "fig10_DA_test_noname010.pdf"),
    ("../2013-05data-assimilation/src/experiments/windowExperiment/window_experiment_plot002.pdf", "fig11_window_experiment_plot002.pdf"),
    ("../2013-05data-assimilation/src/experiments/covInflTest/figures/ETKF_390s_infl_error.pdf", "fig12_ETKF_390s_infl_error.pdf"),
    ("figures/many-thermosyphons.jpg", "fig13_many-thermosyphons.pdf"),
    ("figures/fairbanks-thermosyphon.jpg", "fig14_fairbanks-thermosyphon.pdf"),
    ("../2013-05data-assimilation/papers/harris-tellus-2012-loop.pdf", "fig15_harris-tellus-2012-loop.pdf"),
    ("figures/221TimeSeries.pdf", "fig16_221TimeSeries.pdf"),
    ("figures/convectionLoopYoutubeScreenShot3.png", "fig17_convectionLoopYoutubeScreenShot3.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/OpenFOAM/figures/heating_zoom_mesh4.png", "fig18_heating_zoom_mesh4.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/OpenFOAM/figures/3D-mesh2.png", "fig19_3D-mesh2.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/OpenFOAM/figures/adjacency36000bool01.pdf", "fig20_adjacency36000bool01.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/OpenFOAM/figures/adjacency36000bool02.pdf", "fig21_adjacency36000bool02.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/OpenFOAM/figures/heating003.png", "fig22_heating003.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/presentation/foamLab_slides001.pdf", "fig23_foamLab_slides001.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/src/experiments/meshVerification/Flux-end-20-times.pdf", "fig24_Flux-end-20-times.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/presentation/foamLab_slides002.pdf", "fig25_foamLab_slides002.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/presentation/foamLab_slides003.pdf", "fig26_foamLab_slides003.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/src/experiments/openFoamAssimilation/data/synData-tStep.01-b290-t340-m40000/results_vs_N_32_w10_labels.pdf", "fig27_results_vs_N_32_w10_labels.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/src/experiments/openFoamAssimilation/data/synData-tStep.01-b290-t340-m40000/results_vs_N_40000_w10_labels.pdf", "fig28_results_vs_N_40000_w10_labels.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/src/experiments/openFoamAssimilation/data/synData-tStep.01-b290-t340-m40000-noRenum/errorAll005.pdf", "fig29_errorAll005.pdf"),
    ("/Users/andyreagan/work/2013/2013-05data-assimilation/presentation/foamLab_slides004.pdf", "fig30_foamLab_slides004.pdf"),
]

# \input directives that should be dropped entirely rather than expanded.
# \currfilebase resolves to the top-level file base (reagan-thesis-main),
# but the settings file only defines \filenamebase, which becomes unnecessary
# once all \input{\filenamebase.X} lines are inlined.
DROP_INPUTS = {"currfilebase.settings"}

INPUT_RE = re.compile(r"\\input\{\\(currfilebase|filenamebase)\.([^}]+)\}")
BIB_RE = re.compile(r"^\\bibliography\{[^}]+\}\s*$")


def strip_comments(text: str) -> str:
    """Remove %% comments. Full-line comments drop the line entirely; inline
    comments are cut at the first unescaped %% (preserving preceding chars).
    """
    out_lines = []
    for line in text.splitlines(keepends=True):
        # Separate the line from its trailing newline (preserve line ending).
        if line.endswith("\r\n"):
            body, eol = line[:-2], "\r\n"
        elif line.endswith("\n"):
            body, eol = line[:-1], "\n"
        else:
            body, eol = line, ""
        stripped = body.lstrip()
        if stripped.startswith("%%"):
            # Drop entire line including its line terminator.
            continue
        idx = body.find("%%")
        if idx >= 0:
            body = body[:idx]
        out_lines.append(body + eol)
    return "".join(out_lines)


def resolve_input(prefix: str, suffix: str) -> Path:
    """Map an \\input{\\prefix.suffix} reference to its source file path."""
    if prefix == "currfilebase":
        return REPO / f"{BASE}-main.{suffix}.tex"
    return REPO / f"{BASE}.{suffix}.tex"


def expand_inputs(text: str, bbl_content: str) -> str:
    out = []
    for line in text.splitlines(keepends=True):
        m = INPUT_RE.search(line)
        if m:
            key = f"{m.group(1)}.{m.group(2)}"
            if key in DROP_INPUTS:
                continue  # drop the line entirely
            src = resolve_input(m.group(1), m.group(2))
            if not src.exists():
                raise FileNotFoundError(src)
            content = strip_comments(src.read_text())
            # Splice content in place of the \input{} token, keeping any
            # surrounding text on the same line.
            out.append(line[:m.start()] + content + line[m.end():].lstrip("\n"))
        elif BIB_RE.match(line):
            out.append(bbl_content)
            if not bbl_content.endswith(("\n", "\r\n")):
                out.append("\n")
        else:
            out.append(line)
    return "".join(out)


def collapse_blank_runs(text: str) -> str:
    """Collapse any run of 2+ consecutive blank lines down to 1."""
    out = []
    blank = False
    for line in text.splitlines(keepends=True):
        is_blank = line.strip() == ""
        if is_blank and blank:
            continue
        out.append(line)
        blank = is_blank
    return "".join(out)


def build(variant: str = "root") -> str:
    main = strip_comments(MAIN.read_text())
    bbl = BBL.read_text() if BBL.exists() else ""
    out = expand_inputs(main, bbl)
    out = collapse_blank_runs(out)
    if variant == "package":
        for old, new in PACKAGE_FIGURE_REMAP:
            out = out.replace(old, new)
    return out


PACKAGE_COMBINED = REPO / "package" / f"{BASE}-main-combined.tex"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", choices=("root", "package"), default="root",
                    help="'root' produces reagan-thesis-main-combined.tex; "
                         "'package' additionally remaps figure paths to the "
                         "arXiv-friendly fig01..fig30 names.")
    ap.add_argument("--check", action="store_true",
                    help="Compare against the committed combined file; exit 1 on diff.")
    ap.add_argument("output", nargs="?",
                    help="Output path. Defaults to the repo-canonical location "
                         "for the chosen variant.")
    args = ap.parse_args()

    if not BBL.exists():
        print(f"error: {BBL.name} not found. Run:\n"
              f"  pdflatex -draftmode {MAIN.name} && bibtex {BASE}-main",
              file=sys.stderr)
        return 2

    target = Path(args.output) if args.output else (PACKAGE_COMBINED if args.variant == "package" else COMBINED)
    generated = build(args.variant)

    if args.check:
        current = target.read_bytes() if target.exists() else b""
        if generated.encode("utf-8") == current:
            print(f"combine-thesis: {target.name} matches generator output ({args.variant}).")
            return 0
        print(f"combine-thesis: {target.name} differs from generator output ({args.variant}).",
              file=sys.stderr)
        return 1

    target.write_text(generated)
    print(f"wrote {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

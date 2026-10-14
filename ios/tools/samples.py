#!/usr/bin/env python3
"""Makes the sample photo (a handwritten-style note) and PDF (a short lease)
that the App Store screenshots attach.   python3 tools/samples.py OUTDIR"""
import subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)

im = Image.new("RGB", (1200, 900), (250, 246, 232))
d = ImageDraw.Draw(im)
f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Bradley Hand Bold.ttf", 64)
y = 90
for line in ["Reminder!", "Dentist - Thursday 3:30pm", "Bring insurance card", "Pick up Mia at 5", "Buy: eggs, oat milk, basil"]:
    d.text((90, y), line, fill=(30, 40, 90), font=f)
    y += 140
im.save(out / "note.jpg", quality=90)

lease = out / "lease.txt"
lease.write_text("""RESIDENTIAL TENANCY AGREEMENT - KEY TERMS

Rent: 1,250 pounds per month, due on the 1st of each month by bank transfer.
Deposit: 1,450 pounds, held in a government-approved deposit scheme.
Term: 12 months starting 1 November 2026, with a break clause after 6 months (2 months' written notice).
Pets: Not allowed without the landlord's written permission.
Repairs: The landlord is responsible for the boiler, plumbing and structure. The tenant must report problems within 7 days.
Ending the tenancy: The tenant must give 2 months' notice in writing. The property must be returned clean, with all keys.
Late rent: A fee of 25 pounds applies if rent is more than 14 days late.
""")
with open(out / "lease.pdf", "wb") as pdf:
    subprocess.run(["cupsfilter", str(lease)], stdout=pdf, stderr=subprocess.DEVNULL, check=True)
print(out)

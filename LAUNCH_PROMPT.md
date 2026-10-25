Implement from the current JAKE DRIVE repository/package directly. Do not redesign it and do not consult older packages.

Read START_HERE.md and DESIGN_MASTER.md first. The target is the approved PURE landscape shot: centered hero speed, no km/h/tach/cards/Union Jack, small gear at hero lower-right, small green MINI companion car on the right-lower roadway, wet arched tunnel, and dark 0/1 rain derived from “一路平安”.

Use the existing Swift + Metal renderer. Preserve the exact camera, timing, material, car-master, glyph and render-pass contracts. Do not substitute a generic font; do not re-cut the vehicle from brightness; do not blur the hero speed/gear; do not infer gear/brake.

First milestone on Mac/iPhone is compilation + native visual evidence for 0/20/72/88/100/128 and all G-buffer debug modes. If visual output is below Reference/APPROVED.png, improve the existing scene/material/shader path before BLE work.

Binary art masters are in the final distribution archive and have SHA-256 values documented in Source/Vehicle/README.md. Missing binary masters are not permission to generate placeholders.

Report actual commands and PASS/FAIL/NOT RUN. Never call Linux parsing an Apple build and never claim 60fps/visual acceptance without native evidence.

#!/usr/bin/env python3
"""
gemini_bot.py — Automate sprite sheet generation via the Gemini web UI.

Uses Playwright + a dedicated Chrome profile so no login is needed after the
first run.  Supports parallel mode to generate all animation sheets at once.

Single sheet:
    python3 tools/sprite-gen/gemini_bot.py <prompt> <output> [attachment]

Parallel (all animation sheets at once, 4 Chrome windows):
    python3 tools/sprite-gen/gemini_bot.py --parallel <attachment> \\
        <prompt1> <out1> <prompt2> <out2> <prompt3> <out3> <prompt4> <out4>
"""

import asyncio
import shutil
import sys
import time
from pathlib import Path

SPRITE_DIR  = Path(__file__).parent.parent.parent / "godot" / "sprites"
BOT_PROFILE = Path.home() / ".barony-bot-chrome"   # main profile (logged-in session)

# ---------------------------------------------------------------------------
# Selector catalogue
# ---------------------------------------------------------------------------
INPUT_SELECTORS = [
    "rich-textarea .ql-editor",
    "div.ql-editor[contenteditable]",
    "p.textarea-font-size",
    "div[contenteditable='true']",
]
SEND_SELECTORS = [
    "button[aria-label='Send message']",
    "button[data-mat-icon-name='send']",
    "button[aria-label*='Send']",
    "mat-icon[fonticon='send']",
]
ATTACH_SELECTORS = [
    "button[aria-label='Upload & tools']",
    "button[aria-label='Add images and more']",
    "button[aria-label*='Upload']",
    "button[aria-label*='attach' i]",
]
IMAGE_SELECTORS = [
    "img[src*='blob:']",
    "img.generated-image",
    ".image-generation-result img",
    "model-response img",
    "message-content img",
]
DOWNLOAD_SELECTORS = [
    "button[aria-label='Download full size image']",
    "button[aria-label='Download']",
    "button[aria-label*='download' i]",
    "[data-tooltip*='Download']",
    "button[mattooltip*='Download' i]",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
async def find_first(page, selectors: list, timeout_ms: int = 5000):
    deadline = time.time() + timeout_ms / 1000
    while time.time() < deadline:
        for sel in selectors:
            try:
                el = await page.query_selector(sel)
                if el:
                    return el, sel
            except Exception:
                pass
        await asyncio.sleep(0.2)
    return None, None


async def wait_for_first(page, selectors: list, timeout_ms: int = 30000):
    deadline = time.time() + timeout_ms / 1000
    while time.time() < deadline:
        el, sel = await find_first(page, selectors, timeout_ms=500)
        if el:
            return el, sel
        await asyncio.sleep(0.3)
    return None, None


def _ensure_worker_profile(worker_id: int) -> Path:
    """Clone the main bot profile into a worker-specific directory.

    Copies only the session-critical files (skipping caches) so subsequent
    parallel runs are fast.  Always clears Chrome singleton locks.
    """
    dst = Path.home() / f".barony-bot-chrome-w{worker_id}"

    if not (dst / "Default" / "Cookies").exists():
        print(f"[w{worker_id}] First-time profile clone — copying session...")
        if dst.exists():
            shutil.rmtree(str(dst))
        # Skip binary caches — they're large and not needed for login
        _NO_COPY = {"Cache", "Code Cache", "GPUCache", "ShaderCache",
                    "Service Worker", "CacheStorage"}
        shutil.copytree(
            str(BOT_PROFILE), str(dst),
            ignore=lambda _dir, names: [n for n in names if n in _NO_COPY],
        )
        print(f"[w{worker_id}] Profile ready.")

    for lock in ["SingletonLock", "SingletonCookie", "SingletonSocket"]:
        (dst / lock).unlink(missing_ok=True)

    return dst


# ---------------------------------------------------------------------------
# Core bot — one browser window, one generation
# ---------------------------------------------------------------------------
async def run(
    prompt: str,
    output_filename: str,
    attachment_filename: str = None,
    profile_dir: Path = None,
    label: str = "",
    download_lock: asyncio.Lock = None,
):
    from playwright.async_api import async_playwright

    profile      = profile_dir or BOT_PROFILE
    output_path  = SPRITE_DIR / output_filename
    output_path.parent.mkdir(parents=True, exist_ok=True)
    attachment_path = (SPRITE_DIR / attachment_filename) if attachment_filename else None
    tag = f"[{label}] " if label else ""

    if attachment_path and not attachment_path.exists():
        raise RuntimeError(f"Attachment not found: {attachment_path}")

    print(f"\n{'='*60}")
    print(f"{tag}Gemini Bot — generating: {output_filename}")
    if attachment_path:
        print(f"{tag}Attachment:             {attachment_path.name}")
    print(f"{'='*60}\n")

    for lock in ["SingletonLock", "SingletonCookie", "SingletonSocket"]:
        (profile / lock).unlink(missing_ok=True)

    async with async_playwright() as pw:
        first_run = not (profile / "Default" / "Cookies").exists()
        if first_run:
            print(f"{tag}First run — sign into Google in the browser window, then close it.")
            print(f"{tag}Re-run afterwards to generate sprites.\n")

        context = await pw.chromium.launch_persistent_context(
            str(profile),
            channel="chrome",
            headless=False,
            slow_mo=60,
            args=["--disable-blink-features=AutomationControlled"],
            accept_downloads=True,
            ignore_default_args=["--enable-automation"],
        )

        if first_run:
            page = context.pages[0] if context.pages else await context.new_page()
            await page.goto("https://accounts.google.com")
            await context.wait_for_event("close", timeout=300000)
            print(f"{tag}Signed in — re-run to generate.")
            return

        page = context.pages[0] if context.pages else await context.new_page()

        # Network capture — only after prompt is sent (avoids page-load UI assets)
        captured_images: list = []
        capture_active = False

        async def _capture(response):
            if not capture_active:
                return
            url = response.url
            # Skip Gemini's own UI assets (sparkle icon, avatars, etc.)
            if "gstatic.com" in url or "gemini_sparkle" in url:
                return
            ct = response.headers.get("content-type", "")
            if any(t in ct for t in ("image/png", "image/jpeg", "image/webp")):
                try:
                    body = await response.body()
                    if len(body) > 200_000:  # generated sprite sheets are 800KB+; skip thumbnails
                        captured_images.append((ct, body))
                except Exception:
                    pass

        page.on("response", _capture)

        print(f"{tag}Opening Gemini...")
        await page.goto("https://gemini.google.com/app", wait_until="domcontentloaded")
        await page.wait_for_timeout(1500)
        # Try to start a fresh chat so there's at most one download button per run.
        # The image-count baseline (img_count_before) handles the case where we
        # can't start a new chat — we just wait for the count to increase.
        for _btn_sel in [
            "button[aria-label='New chat']",
            "button[aria-label='Start new chat']",
            "a[aria-label='New chat']",
            "[data-test-id='new-chat-button']",
        ]:
            _btn = await page.query_selector(_btn_sel)
            if _btn:
                _bbox = await _btn.bounding_box()
                if _bbox and _bbox["width"] > 0:
                    await _btn.click()
                    await page.wait_for_timeout(1500)
                    break

        # ── Attachment ────────────────────────────────────────────────────────
        if attachment_path:
            print(f"{tag}Attaching {attachment_path.name}...")
            attach_el, _ = await wait_for_first(page, ATTACH_SELECTORS, timeout_ms=15000)
            if attach_el:
                await attach_el.click()
                await page.wait_for_timeout(600)
                upload_item = await page.query_selector("[role='menuitem'][aria-label*='Upload files']")
                if not upload_item:
                    upload_item = await page.query_selector("[role='menuitem']:has-text('Upload files')")
                try:
                    async with page.expect_file_chooser(timeout=8000) as fc_info:
                        if upload_item:
                            await upload_item.click()
                    fc = await fc_info.value
                    await fc.set_files(str(attachment_path))
                    await page.wait_for_timeout(1500)
                    print(f"{tag}  Attached {attachment_path.name}")
                except Exception as e:
                    file_input = await page.query_selector('input[type="file"]')
                    if file_input:
                        await file_input.set_input_files(str(attachment_path))
                        await page.wait_for_timeout(1000)
                    else:
                        print(f"{tag}WARNING: Could not attach image ({e}) — sending without.")
            else:
                print(f"{tag}WARNING: Attachment button not found — sending without image.")

        # ── Prompt ───────────────────────────────────────────────────────────
        print(f"{tag}Typing prompt...")
        input_el, _ = await wait_for_first(page, INPUT_SELECTORS, timeout_ms=20000)
        if not input_el:
            await context.close()
            raise RuntimeError(f"Text input not found — is Chrome logged into Google? (profile: {profile})")

        await input_el.click()
        await page.wait_for_timeout(300)
        await page.keyboard.type(prompt, delay=10)
        await page.wait_for_timeout(500)

        # ── Send ──────────────────────────────────────────────────────────────
        print(f"{tag}Sending...")
        send_el, _ = await find_first(page, SEND_SELECTORS, timeout_ms=5000)
        capture_active = True
        if send_el:
            await send_el.click()
        else:
            await input_el.press("Enter")

        # ── Wait for image ────────────────────────────────────────────────────
        # Count images already on page BEFORE generation so we wait for a NEW one
        img_count_before = 0
        for _sel in IMAGE_SELECTORS:
            _els = await page.query_selector_all(_sel)
            if _els:
                img_count_before = len(_els)
                break

        print(f"{tag}Waiting for generation (up to 3 min, baseline {img_count_before} images)...")

        async def _wait_for_new_image(timeout_ms: int):
            deadline = time.time() + timeout_ms / 1000
            while time.time() < deadline:
                for _sel in IMAGE_SELECTORS:
                    _els = await page.query_selector_all(_sel)
                    if len(_els) > img_count_before:
                        return _els[-1]
                await asyncio.sleep(0.5)
            return None

        img_el = await _wait_for_new_image(180000)
        if not img_el:
            print(f"{tag}No new image after 3 min — waiting 5 more...")
            img_el = await _wait_for_new_image(300000)

        await page.wait_for_timeout(1500)

        # ── Download ──────────────────────────────────────────────────────────
        # Generation runs in parallel; downloads are serialized via download_lock
        # so only one window hovers at a time (avoids OS focus conflicts).
        print(f"{tag}Downloading...")
        downloaded = False

        # Re-find the last generated image
        all_imgs = []
        for sel in IMAGE_SELECTORS:
            els = await page.query_selector_all(sel)
            if els:
                all_imgs = els
                break
        if all_imgs:
            img_el = all_imgs[-1]

        async def _do_hover_download():
            nonlocal downloaded
            await page.bring_to_front()
            await page.wait_for_timeout(500)

            # Re-query fresh — original handle goes stale if Gemini re-renders
            fresh_imgs = []
            for sel in IMAGE_SELECTORS:
                els = await page.query_selector_all(sel)
                if els:
                    fresh_imgs = els
                    break
            if not fresh_imgs:
                raise Exception("no image element at download time")
            fresh_img = fresh_imgs[-1]

            # Retry hover up to 3 times — first attempt may miss if Gemini is
            # still settling the DOM after generation completes
            dl_el = None
            dl_bbox = None
            for attempt in range(3):
                try:
                    await fresh_img.scroll_into_view_if_needed()
                    await fresh_img.hover(timeout=5000)
                except Exception:
                    # Element went stale — re-query and retry
                    for sel in IMAGE_SELECTORS:
                        els = await page.query_selector_all(sel)
                        if els:
                            fresh_img = els[-1]
                            break
                    await fresh_img.scroll_into_view_if_needed()
                    await fresh_img.hover(timeout=5000)

                await page.wait_for_timeout(1500 + attempt * 500)

                # Scope to LAST model-response to avoid old buttons from prior turns
                found_bbox = await page.evaluate("""() => {
                    const sels = [
                        'button[aria-label="Download full size image"]',
                        'button[aria-label="Download"]',
                        'button[aria-label*="ownload"]'
                    ];
                    // Try last model-response first, fall back to full document
                    const containers = [
                        ...Array.from(document.querySelectorAll('model-response')).slice(-1),
                        document
                    ];
                    for (const container of containers) {
                        for (const sel of sels) {
                            const els = Array.from(container.querySelectorAll(sel));
                            if (els.length) {
                                const el = els[els.length - 1];
                                const r = el.getBoundingClientRect();
                                if (r.width > 0 && r.height > 0) {
                                    return {x: r.left, y: r.top, width: r.width, height: r.height,
                                            label: el.getAttribute('aria-label')};
                                }
                            }
                        }
                    }
                    return null;
                }""")

                if found_bbox:
                    dl_bbox = found_bbox
                    print(f"{tag}  Download btn '{found_bbox['label']}' at ({found_bbox['x']:.0f},{found_bbox['y']:.0f})")
                    break

                if attempt == 2:
                    btns = await page.evaluate("""() =>
                        Array.from(document.querySelectorAll('button'))
                            .map(b => b.getAttribute('aria-label') || b.textContent.trim())
                            .filter(t => t).slice(0, 20)
                    """)
                    raise Exception(f"no visible download button after {attempt+1} hover attempts. Buttons: {btns}")

            # Use page.mouse.click() at the button's stored coordinates.
            # This lets Playwright properly intercept the download event — JS el.click()
            # bypasses Playwright's download interception in some Chromium builds.
            cx = dl_bbox['x'] + dl_bbox['width'] / 2
            cy = dl_bbox['y'] + dl_bbox['height'] / 2

            new_pages: list = []
            page.context.on("page", lambda p: new_pages.append(p))

            try:
                async with page.expect_download(timeout=20000) as dl_info:
                    await page.mouse.click(cx, cy)
                    print(f"{tag}  Mouse-clicked at ({cx:.0f},{cy:.0f})")
                dl = await dl_info.value
                await dl.save_as(output_path)
                downloaded = True
                print(f"{tag}Saved → {output_path.relative_to(Path.cwd())} (mouse click)")
            except Exception as de:
                print(f"{tag}  Mouse click failed ({de}), new_pages={len(new_pages)}")
                if new_pages:
                    new_pg = new_pages[-1]
                    try:
                        await new_pg.wait_for_load_state("networkidle", timeout=15000)
                        img_url = new_pg.url
                        print(f"{tag}  New tab URL: {img_url[:100]}")
                        resp = await new_pg.request.get(img_url)
                        body = await resp.body()
                        output_path.write_bytes(body)
                        await new_pg.close()
                        downloaded = True
                        print(f"{tag}Saved → {output_path.relative_to(Path.cwd())} (new tab, {len(body)//1024}KB)")
                    except Exception as e2:
                        raise Exception(f"new tab download failed: {e2}")
                else:
                    # Last-resort: JS click as fallback (some Chromium builds handle it)
                    try:
                        async with page.expect_download(timeout=15000) as dl_info2:
                            clicked_label = await page.evaluate(f"""() => {{
                                const sels = [
                                    'button[aria-label="Download full size image"]',
                                    'button[aria-label="Download"]',
                                    'button[aria-label*="ownload"]'
                                ];
                                const containers = [
                                    ...Array.from(document.querySelectorAll('model-response')).slice(-1),
                                    document
                                ];
                                for (const c of containers) {{
                                    for (const sel of sels) {{
                                        const els = Array.from(c.querySelectorAll(sel));
                                        if (els.length) {{
                                            const el = els[els.length - 1];
                                            el.click();
                                            return el.getAttribute('aria-label');
                                        }}
                                    }}
                                }}
                                return null;
                            }}""")
                            print(f"{tag}  JS-fallback clicked: '{clicked_label}'")
                        dl2 = await dl_info2.value
                        await dl2.save_as(output_path)
                        downloaded = True
                        print(f"{tag}Saved → {output_path.relative_to(Path.cwd())} (JS fallback)")
                    except Exception as de2:
                        raise Exception(f"mouse click failed: {de}; JS fallback: {de2}")

        if img_el:
            try:
                if download_lock:
                    async with download_lock:
                        await _do_hover_download()
                else:
                    await _do_hover_download()
            except Exception as e:
                print(f"{tag}  Hover download failed: {e}")

        # Fallback: largest network-captured image (>200KB, non-UI)
        if not downloaded and captured_images:
            try:
                _, body = max(captured_images, key=lambda x: len(x[1]))
                output_path.write_bytes(body)
                downloaded = True
                print(f"{tag}Saved → {output_path.relative_to(Path.cwd())} (network {len(body)//1024}KB)")
            except Exception as e:
                print(f"{tag}  Network save failed: {e}")

        if downloaded:
            await page.wait_for_timeout(500)
            try:
                await context.close()
            except Exception:
                pass
            print(f"{tag}Done!")
        else:
            if download_lock:
                # Parallel mode — can't block waiting for manual save
                print(f"{tag}Auto-download failed. Save manually: {output_path}")
                try:
                    await context.close()
                except Exception:
                    pass
                raise RuntimeError(f"download failed for {output_filename}")
            else:
                print(f"{tag}Auto-download failed.")
                print(f"{tag}Right-click the image in Chrome → 'Save image as...' →")
                print(f"{tag}  {output_path}")
                print(f"{tag}Close Chrome when done.")
                try:
                    await context.wait_for_event("close", timeout=600000)
                except Exception:
                    pass
                sys.exit(1)


# ---------------------------------------------------------------------------
# Parallel runner — N sheets simultaneously, each in its own Chrome window
# ---------------------------------------------------------------------------
async def run_parallel(sheets: list[tuple], attachment_filename: str):
    """sheets = list of (prompt, output_filename) — all share the same attachment.

    Generation runs fully in parallel; the download step is serialized via a
    shared lock so only one Chrome window hovers at a time (avoids OS focus
    conflicts that prevent the download button from appearing).
    """
    profiles = [_ensure_worker_profile(i) for i in range(len(sheets))]
    lock = asyncio.Lock()

    tasks = [
        run(
            prompt=prompt,
            output_filename=out,
            attachment_filename=attachment_filename,
            profile_dir=profiles[i],
            label=f"w{i} {out}",
            download_lock=lock,
        )
        for i, (prompt, out) in enumerate(sheets)
    ]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    failed = [sheets[i][1] for i, r in enumerate(results) if isinstance(r, Exception)]
    if failed:
        print(f"\nFailed sheets: {failed}")
        print("Re-run individually with: python3 tools/sprite-gen/gemini_bot.py <prompt> <out> <attachment>")
        sys.exit(1)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    args = sys.argv[1:]

    if args and args[0] == "--parallel":
        # --parallel <attachment> <p1> <o1> <p2> <o2> ...
        if len(args) < 5 or (len(args) - 2) % 2 != 0:
            print("Usage: gemini_bot.py --parallel <attachment> <prompt1> <out1> [<prompt2> <out2> ...]")
            sys.exit(1)
        attachment = args[1]
        pairs = args[2:]
        sheets = [(pairs[i], pairs[i + 1]) for i in range(0, len(pairs), 2)]
        print(f"Parallel mode: {len(sheets)} sheets × 1 Chrome each")
        asyncio.run(run_parallel(sheets, attachment))
    else:
        if len(args) < 2:
            print(__doc__)
            sys.exit(1)
        prompt     = args[0]
        output     = args[1]
        attachment = args[2] if len(args) > 2 else None
        asyncio.run(run(prompt, output, attachment))


if __name__ == "__main__":
    main()

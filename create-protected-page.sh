#!/usr/bin/env bash
# create-protected-page.sh
#
# Interactively builds a small, self-contained HTML page for one project.
# You give it a project name, a link, and (optionally) a background image
# filename for its entry on your main "diary stack" index.html. Optionally
# you also set a password — the password itself is never stored: only its
# SHA-512 hash is written into the page. When someone opens the page,
# JavaScript hashes whatever they type (using the browser's built-in
# SHA-512) and compares it to the stored hash. If it matches, the browser
# is sent to your link.
#
# IMPORTANT — please read:
# This is a casual "keep it out of sight" gate, not real security. The
# hash lives in the page's own source, so anyone who views source has
# everything needed to try to crack it offline, and anyone who reads the
# JavaScript can see the destination link. Don't use this to protect
# anything sensitive.
#
# This version wires the new project into the "diary stack" style
# index.html (each project is a full-screen <section class="page
# project-page"> with its own background image, a PAGE NN kicker, a
# proj-btn, and a matching dot in the .page-dots progress indicator) —
# not the older two-theme "My Projects" layout with <nav> buttons.

set -euo pipefail

# ---------- helpers ----------------------------------------------------

json_escape() {
  # Escapes backslashes and double quotes so a value can sit safely
  # inside a JS/HTML double-quoted string.
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

html_escape() {
  # Escapes &, <, >, " so a value can sit safely as HTML text/attribute content.
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  printf '%s' "$s"
}

css_escape() {
  # Escapes backslashes and single quotes so a value can sit safely
  # inside a CSS url('...') string.
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\'/\\\'}"
  printf '%s' "$s"
}

sha512_hex() {
  # Prints the lowercase hex SHA-512 digest of stdin, no trailing newline
  # in the input that gets hashed.
  if command -v sha512sum >/dev/null 2>&1; then
    sha512sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 512 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha512 | awk '{print $NF}'
  else
    echo "No sha512sum, shasum, or openssl found on this system." >&2
    exit 1
  fi
}

# ---------- gather input -------------------------------------------------

read -rp "Project name: " PROJECT_NAME
while [[ -z "$PROJECT_NAME" ]]; do
  read -rp "Project name (required): " PROJECT_NAME
done

read -rp "Project link (URL): " PROJECT_LINK
while [[ -z "$PROJECT_LINK" ]]; do
  read -rp "Project link (required): " PROJECT_LINK
done

read -rp "Background image filename for this project's page (e.g. myproject.png), kept in the same folder as index.html: " BG_IMAGE
while [[ -z "$BG_IMAGE" ]]; do
  read -rp "Background image filename (required): " BG_IMAGE
done

read -rp "Protect this page with a password? (y/n): " USE_PASSWORD
USE_PASSWORD=$(printf '%s' "$USE_PASSWORD" | tr '[:upper:]' '[:lower:]')

PASSWORD_HASH=""
if [[ "$USE_PASSWORD" == "y" || "$USE_PASSWORD" == "yes" ]]; then
  while true; do
    read -rsp "Password: " PASSWORD; echo
    read -rsp "Confirm password: " PASSWORD_CONFIRM; echo
    if [[ "$PASSWORD" == "$PASSWORD_CONFIRM" && -n "$PASSWORD" ]]; then
      break
    fi
    echo "Passwords empty or didn't match — try again."
  done
  PASSWORD_HASH=$(printf '%s' "$PASSWORD" | sha512_hex)
  unset PASSWORD PASSWORD_CONFIRM
  PROTECTED="true"
else
  PROTECTED="false"
fi

# ---------- build output filename ----------------------------------------

SAFE_NAME=$(printf '%s' "$PROJECT_NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -cs 'a-z0-9' '-' \
  | sed 's/^-*//; s/-*$//')
[[ -z "$SAFE_NAME" ]] && SAFE_NAME="project"

OUTPUT_DIR="${1:-.}"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/${SAFE_NAME}.html"

if [[ -e "$OUTPUT_FILE" ]]; then
  read -rp "$OUTPUT_FILE already exists. Overwrite? (y/n): " OVERWRITE
  if [[ "$(printf '%s' "$OVERWRITE" | tr '[:upper:]' '[:lower:]')" != "y" ]]; then
    echo "Aborted, nothing written."
    exit 1
  fi
fi

ESC_NAME=$(json_escape "$PROJECT_NAME")
ESC_LINK=$(json_escape "$PROJECT_LINK")

# ---------- write the page ------------------------------------------------

cat > "$OUTPUT_FILE" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${ESC_NAME}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Cabin+Sketch:wght@400;700&family=Permanent+Marker&display=swap" rel="stylesheet">
<style>
  :root{
    --paper:#e9e4d9; --paper2:#ded7c8; --ink:#211d18; --ink-soft:#5b5348;
  }
  @media (prefers-color-scheme: dark){
    :root{ --paper:#15130f; --paper2:#1d1a15; --ink:#e8e1d2; --ink-soft:#b4ab9b; }
  }
  *{box-sizing:border-box;}
  html,body{ margin:0; min-height:100%; background:var(--paper); }
  body{
    display:flex; align-items:center; justify-content:center;
    min-height:100vh; padding:24px;
    font-family:'Cabin Sketch', system-ui, sans-serif;
    color:var(--ink);
  }
  .card{
    width:100%; max-width:380px; text-align:center;
    border:1.5px solid var(--ink); border-radius:4px;
    padding:36px 28px; background:var(--paper2);
    box-shadow:4px 4px 0 rgba(0,0,0,0.12);
  }
  .icon{ font-size:2.2rem; margin-bottom:6px; }
  h1{
    font-family:'Permanent Marker', cursive; font-weight:400;
    font-size:1.6rem; margin:4px 0 20px; transform:rotate(-1.5deg);
  }
  input[type="password"]{
    width:100%; padding:10px 12px; font-size:1rem;
    border:1.4px solid var(--ink); border-radius:3px;
    background:var(--paper); color:var(--ink);
    font-family:inherit; margin-bottom:14px;
  }
  button{
    width:100%; padding:11px; font-size:1rem; font-weight:700;
    letter-spacing:0.05em; font-family:'Cabin Sketch', cursive;
    border:1.4px solid var(--ink); border-radius:3px; cursor:pointer;
    background:var(--ink); color:var(--paper);
  }
  button:active{ transform:scale(0.98); }
  .error{
    color:#a83232; font-size:0.85rem; margin-top:12px; min-height:1.2em;
  }
  .status{ font-size:0.85rem; color:var(--ink-soft); margin-top:12px; min-height:1.2em; }
  @keyframes shake{
    0%,100%{ transform:translateX(0); }
    20%,60%{ transform:translateX(-6px); }
    40%,80%{ transform:translateX(6px); }
  }
  .shake{ animation:shake 0.35s ease; }
</style>
</head>
<body>
  <div class="card" id="card">
    <div class="icon">🔒</div>
    <h1>${ESC_NAME}</h1>
    <form id="gate-form" autocomplete="off">
      <input type="password" id="pw" placeholder="Enter password" required>
      <button type="submit">Unlock</button>
      <div class="error" id="error"></div>
      <div class="status" id="status"></div>
    </form>
  </div>

<script>
  const STORED_HASH = "${PASSWORD_HASH}";
  const TARGET_LINK = "${ESC_LINK}";

  async function sha512Hex(text){
    const bytes = new TextEncoder().encode(text);
    const digest = await crypto.subtle.digest('SHA-512', bytes);
    return Array.from(new Uint8Array(digest))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  }

  const form = document.getElementById('gate-form');
  const input = document.getElementById('pw');
  const errorEl = document.getElementById('error');
  const statusEl = document.getElementById('status');
  const card = document.getElementById('card');

  form.addEventListener('submit', async function(e){
    e.preventDefault();
    errorEl.textContent = '';
    statusEl.textContent = 'Checking…';
    const hash = await sha512Hex(input.value);
    if (hash === STORED_HASH) {
      statusEl.textContent = 'Unlocked — redirecting…';
      window.location.href = TARGET_LINK;
    } else {
      statusEl.textContent = '';
      errorEl.textContent = 'Wrong password, try again.';
      input.value = '';
      input.focus();
      card.classList.remove('shake');
      void card.offsetWidth;
      card.classList.add('shake');
    }
  });
</script>
</body>
</html>
HTML

if [[ "$PROTECTED" == "false" ]]; then
  # No password wanted — replace the gate page with a plain auto-redirect page.
  cat > "$OUTPUT_FILE" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="0; url=${ESC_LINK}">
<title>${ESC_NAME}</title>
<style>
  body{ font-family:system-ui, sans-serif; display:flex; align-items:center;
        justify-content:center; min-height:100vh; margin:0; background:#eae5dc; }
  a{ color:#211d18; }
</style>
</head>
<body>
  <p>Redirecting to ${ESC_NAME}… if nothing happens, <a href="${ESC_LINK}">click here</a>.</p>
  <script>window.location.href = "${ESC_LINK}";</script>
</body>
</html>
HTML
fi

echo
echo "Created: $OUTPUT_FILE"
if [[ "$PROTECTED" == "true" ]]; then
  echo "Password protected — SHA-512 hash embedded, plaintext password was not saved anywhere."
else
  echo "No password — this page just redirects straight to the link."
fi

# ---------- optionally wire a new page into index.html ---------------------

echo
read -rp "Add a project page for this on your main index.html? (y/n): " ADD_BTN
ADD_BTN=$(printf '%s' "$ADD_BTN" | tr '[:upper:]' '[:lower:]')

if [[ "$ADD_BTN" == "y" || "$ADD_BTN" == "yes" ]]; then
  read -rp "Path to index.html [./index.html]: " INDEX_PATH
  INDEX_PATH="${INDEX_PATH:-./index.html}"

  if [[ ! -f "$INDEX_PATH" ]]; then
    echo "Couldn't find $INDEX_PATH — skipping. You can wire it in by hand, or re-run this step later."
  else
    # Fixed anchors this script relies on in the "diary stack" layout.
    CSS_BG_MARKER='  .page:nth-of-type(1) { z-index: 1; }'
    CSS_ZIDX_MARKER='  .page-inner {'
    DOTS_OPEN_MARKER='<div class="page-dots" aria-hidden="true">'
    STACK_OPEN_MARKER='<div class="diary-stack">'

    if ! grep -qF "$CSS_BG_MARKER" "$INDEX_PATH" \
       || ! grep -qF "$CSS_ZIDX_MARKER" "$INDEX_PATH" \
       || ! grep -qF "$DOTS_OPEN_MARKER" "$INDEX_PATH" \
       || ! grep -qF "$STACK_OPEN_MARKER" "$INDEX_PATH"; then
      echo "That file doesn't look like the diary-stack index.html layout this script expects — skipping page insertion."
    else
      cp "$INDEX_PATH" "${INDEX_PATH}.bak"

      REL_HREF=$(html_escape "$(basename "$OUTPUT_FILE")")
      HTML_NAME=$(html_escape "$PROJECT_NAME")
      LABEL_UPPER=$(printf '%s' "$HTML_NAME" | tr '[:lower:]' '[:upper:]')
      INITIAL=$(printf '%s' "$PROJECT_NAME" | cut -c1 | tr '[:lower:]' '[:upper:]')
      ID_SLUG="page-${SAFE_NAME}"
      CSS_IMG=$(css_escape "$BG_IMAGE")

      # Work out where this page lands: how many <section class="page ...>
      # blocks already exist (hero + projects) tells us the next
      # nth-of-type/z-index, and how many are project pages (excluding the
      # hero) tells us the "PAGE NN" number for the kicker label.
      TOTAL_PAGES=$(grep -c '<section class="page' "$INDEX_PATH" || true)
      NEXT_NTH=$((TOTAL_PAGES + 1))
      PAGE_NUM=$((NEXT_NTH - 1))
      PAGE_NUM_PADDED=$(printf '%02d' "$PAGE_NUM")

      # ---- 1) CSS: background-image mapping for #page-<slug> ----
      CSS_BG_FILE=$(mktemp)
      cat > "$CSS_BG_FILE" <<CSS
  #${ID_SLUG} { background-image: linear-gradient(var(--bg-overlay), var(--paper)), url('${CSS_IMG}'); }
CSS

      # ---- 2) CSS: z-index rule for the new nth-of-type ----
      CSS_Z_FILE=$(mktemp)
      cat > "$CSS_Z_FILE" <<CSS
  .page:nth-of-type(${NEXT_NTH}) { z-index: ${NEXT_NTH}; }
CSS

      # ---- 3) a matching dot for .page-dots ----
      DOT_FILE=$(mktemp)
      cat > "$DOT_FILE" <<DOT
  <span class="dot"></span>
DOT

      # ---- 4) the full <section> block for the diary stack ----
      SECTION_FILE=$(mktemp)
      cat > "$SECTION_FILE" <<SECTION
  <!-- ============ PAGE ${PAGE_NUM_PADDED} : ${LABEL_UPPER} ============ -->
  <section class="page project-page" id="${ID_SLUG}">
    <div class="page-inner">
      <div class="page-kicker">PAGE ${PAGE_NUM_PADDED}</div>
      <button class="proj-btn page-btn" type="button" data-url="${REL_HREF}" aria-label="Open ${HTML_NAME} project">
        <svg class="btn-outline" viewBox="0 0 430 92" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
          <polygon points="18,4 412,4 428,46 412,88 18,88 2,46" filter="url(#pencil1)"/>
          <polygon points="14,8 416,7 424,46 416,85 14,84 6,46" filter="url(#pencil2)"/>
        </svg>
        <span class="icon-circle" aria-hidden="true">
          <svg viewBox="0 0 60 60"><circle cx="30" cy="30" r="24" filter="url(#pencil1)"/>
            <text class="glyph" x="30" y="38" font-size="21" text-anchor="middle">${INITIAL}</text>
          </svg>
        </span>
        <span class="label">${LABEL_UPPER}</span>
        <span class="arrow" aria-hidden="true">&rarr;</span>
      </button>
      <svg class="ornament small" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <g stroke="var(--ink)" stroke-width="1.6" filter="url(#pencil2)">
          <path d="M4,20 L36,20"/><path d="M12,6.5 L28,33.5"/><path d="M28,6.5 L12,33.5"/>
        </g>
        <circle cx="20" cy="20" r="1.6" fill="var(--circle-icon)" stroke="none"/>
      </svg>
    </div>
  </section>

SECTION

      # Pass 1: insert the background-image CSS rule right before the
      # fixed ".page:nth-of-type(1)" line (always present, always first).
      awk -v marker="$CSS_BG_MARKER" -v insertfile="$CSS_BG_FILE" '
        { if ($0 == marker && !done) {
            while ((getline line < insertfile) > 0) print line
            close(insertfile); done = 1
          }
          print
        }' "$INDEX_PATH" > "${INDEX_PATH}.tmp1"

      # Pass 2: insert the new z-index rule right before ".page-inner {".
      awk -v marker="$CSS_ZIDX_MARKER" -v insertfile="$CSS_Z_FILE" '
        { if ($0 == marker && !done) {
            while ((getline line < insertfile) > 0) print line
            close(insertfile); done = 1
          }
          print
        }' "${INDEX_PATH}.tmp1" > "${INDEX_PATH}.tmp2"

      # Pass 3: insert a new dot right before the page-dots block's own
      # closing </div> (the first </div> line seen after its opening tag —
      # there's nothing nested inside that block).
      awk -v openmark="$DOTS_OPEN_MARKER" -v insertfile="$DOT_FILE" '
        BEGIN { afterOpen = 0; done = 0 }
        {
          if (!done && afterOpen && $0 ~ /^[[:space:]]*<\/div>[[:space:]]*$/) {
            while ((getline line < insertfile) > 0) print line
            close(insertfile); done = 1; afterOpen = 0
          }
          if (!done && index($0, openmark) > 0) { afterOpen = 1 }
          print
        }' "${INDEX_PATH}.tmp2" > "${INDEX_PATH}.tmp3"

      # Pass 4: insert the new <section> right before the diary-stack's own
      # closing </div>. Found by tracking div-nesting depth from the
      # opening tag onward, since sections contain nested divs of their own.
      awk -v openmark="$STACK_OPEN_MARKER" -v insertfile="$SECTION_FILE" '
        BEGIN { tracking = 0; depth = 0; done = 0 }
        {
          if (!done && !tracking && index($0, openmark) > 0) {
            tracking = 1
            tmp = $0; o = gsub(/<div/, "<div", tmp)
            tmp2 = $0; c = gsub(/<\/div>/, "<\/div>", tmp2)
            depth = o - c
            print
            next
          }
          if (!done && tracking) {
            tmp = $0; o = gsub(/<div/, "<div", tmp)
            tmp2 = $0; c = gsub(/<\/div>/, "<\/div>", tmp2)
            newdepth = depth + o - c
            if (newdepth <= 0) {
              while ((getline line < insertfile) > 0) print line
              close(insertfile); done = 1; tracking = 0
              print
              next
            } else {
              depth = newdepth
              print
              next
            }
          }
          print
        }' "${INDEX_PATH}.tmp3" > "${INDEX_PATH}.tmp4"

      mv "${INDEX_PATH}.tmp4" "$INDEX_PATH"
      rm -f "${INDEX_PATH}.tmp1" "${INDEX_PATH}.tmp2" "${INDEX_PATH}.tmp3" \
            "$CSS_BG_FILE" "$CSS_Z_FILE" "$DOT_FILE" "$SECTION_FILE"

      echo "Added \"${LABEL_UPPER}\" as PAGE ${PAGE_NUM_PADDED} to $INDEX_PATH — backup saved as ${INDEX_PATH}.bak"
      echo "Its background image is expected at: ${BG_IMAGE} (keep it in the same folder as index.html)."
      echo "Its button opens $(basename "$OUTPUT_FILE") — keep that in the same folder as index.html too."
    fi
  fi
fi

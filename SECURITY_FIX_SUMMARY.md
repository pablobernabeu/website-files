# Security Fix Summary

## 2026-06-06 — Exposed Scopus API key removed

### Issue
A Scopus (Elsevier) API key was committed to the repository in plaintext in
three tracked locations:

- `assets/Scopus API key.txt`
- `content/post/speculation-across-various-scientific-topics/scopus_key.txt`
- `public/2094/speculation-across-various-scientific-topics/scopus_key.txt` (built copy)

Because the repository is public and these files were already committed, the key
must be treated as compromised — deletion alone does **not** remove it from git
history.

### Action taken (working tree)
- Deleted all three files.
- Hardened `.gitignore` with global patterns so no key file can be re-committed:
  ```
  **/scopus_key.txt
  **/Scopus API key.txt
  **/Scopus*key*.txt
  ```
  (The previous, narrower rscopus-specific ignore lines were replaced.)

### Required manual follow-up (cannot be automated)
1. **Rotate the key** in the Elsevier Developer Portal
   (https://dev.elsevier.com/) — revoke the exposed key and issue a new one.
2. **Store the new key as a GitHub Actions secret** named `SCOPUS_API_KEY`
   (already referenced by `.github/workflows/collect-related-references.yml`).
   Do not commit it to any file.
3. (Optional but recommended) **Purge the key from git history** with
   `git filter-repo` or the BFG Repo-Cleaner, then force-push and rotate again.

### Notes
- The `rscopus-plus-...` post's `scopus_key.txt` was already git-ignored and is
  not tracked, so it was not exposed.
- Scripts/workflows read the key from the environment (`SCOPUS_API_KEY`), so the
  committed files were redundant as well as unsafe.

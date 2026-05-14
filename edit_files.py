import re
import os

# Function to handle paths for different OSes (mainly replacing backslashes)
def get_path(path_str):
    # If we're on a Linux-like system (typical for these environments), 
    # we might need to adjust the Windows-style paths.
    # However, I will try to use the paths as provided but adapted for a bash environment.
    # The user provided: c:\Users\pablob\OneDrive - Nexus365\Documents\GitHub\website-files\...
    # This path is likely not present in the current environment. 
    # I should check for the relative structure.
    
    # Assuming the current working directory is the root of the project.
    rel_path_r = 'scripts/collect_related_references.R'
    rel_path_js = 'static/js/related-references.js'
    
    if "collect_related_references.R" in path_str:
        return rel_path_r
    return rel_path_js

# === Edit 1: collect_related_references.R ===
r_path = "scripts/collect_related_references.R"
if os.path.exists(r_path):
    with open(r_path, 'r', encoding='utf-8') as f:
        content = f.read()

    old = '''  citation <- sub(
    "(\\\\.\\\\s+)([^.]+?),\\\\s*(\\\\d{1,4})(?![\\\\u2013\\\\u2014-])(\\\\([^)]+\\\\))?((?:,\\\\s*[\\\\w\\\\d\\\\u2013-]+(?:[\\\\u2013-]\\\\d+)?)*)$",
    "\\\\1*\\\\2*, *\\\\3*\\\\4\\\\5",
    citation,
    perl = TRUE
  )
  # Reject ahead-of-print placeholders'''

    new = '''  citation <- sub(
    "(\\\\.\\\\s+)([^.]+?),\\\\s*(\\\\d{1,4})(?![\\\\u2013\\\\u2014-])(\\\\([^)]+\\\\))?((?:,\\\\s*[\\\\w\\\\d\\\\u2013-]+(?:[\\\\u2013-]\\\\d+)?)*)$",
    "\\\\1*\\\\2*, *\\\\3*\\\\4\\\\5",
    citation,
    perl = TRUE
  )
  # Fallback for conference proceedings and book chapters:
  # ". Container Title, N\u2013M" \u2014 no separate volume/issue number.
  # Only apply when the journal pattern above left no italics (no "*" added).
  if (!grepl("\\\\*", citation, perl = TRUE)) {
    citation <- sub(
      "(\\\\.\\\\s+)([^.]+?),\\\\s*(\\\\d+[\\\\u2013\\\\u2014-]\\\\d+)\\\\s*$",
      "\\\\1*\\\\2*, \\\\3",
      citation,
      perl = TRUE
    )
  }
  # Reject ahead-of-print placeholders'''

    if old in content:
        content = content.replace(old, new, 1)
        with open(r_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("R file: SUCCESS")
    else:
        idx = content.find("# Reject ahead-of-print")
        print("R file: FAILED to find old string")
        if idx != -1:
            print("Context around marker:")
            print(repr(content[max(0,idx-500):idx+50]))
        else:
            print("Marker '# Reject ahead-of-print' not found")
else:
    print(f"R file not found at {r_path}")

# === Edit 2: related-references.js ===
js_path = "static/js/related-references.js"
if os.path.exists(js_path):
    with open(js_path, 'r', encoding='utf-8') as f:
        content2 = f.read()

    idx2 = content2.find('function applyApaItalics(html)')
    if idx2 == -1:
        print("JS file: cannot find applyApaItalics")
    else:
        end_idx = content2.find('\n  }', idx2)
        if end_idx != -1:
             # Find the second closing brace if it's nested or follow the logic
             end_idx = content2.find('\n  }', end_idx + 1)
             if end_idx != -1:
                 end_idx += 4
                 old_fn = content2[idx2:end_idx]
                 print("JS old function:")
                 print(repr(old_fn))
             else:
                 print("JS file: could not find second closing brace")
        else:
             print("JS file: could not find first closing brace")
else:
    print(f"JS file not found at {js_path}")

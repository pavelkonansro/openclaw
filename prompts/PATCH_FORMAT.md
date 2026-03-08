# PATCH_FORMAT

Use unified diffs per file.

## Rules

- Keep diffs minimal.
- One logical change per hunk.
- Avoid whitespace-only churn unless required.
- Do not touch unrelated files.

## Template

```diff
diff --git a/<path> b/<path>
index <old>..<new> 100644
--- a/<path>
+++ b/<path>
@@ -<start>,<count> +<start>,<count> @@
-<old line>
+<new line>
```

## Commit Message Style

- Imperative and specific.
- Example: `scripts: add unified repo check command`

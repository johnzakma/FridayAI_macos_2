# Maintainer Instructions

1. **Always capture work in Git.**
   - Before editing, run `git status` to understand the current state.
   - After each logical change, run:
     ```bash
     git add -A
     git commit -m "Describe the change"
     ```
   - Keep commits focused (UI, backend, docs, etc.) so we can revert individual pieces easily.

2. **Reference this file at the start of every session.**
   - Ensures we remember to use Git, keep entitlements, rules, and workspace handling consistent, and document any workflow-specific rules here.

3. **When adding new automation rules or workflow policies:**
   - Document them in `backend/rules/rules.json`.
   - Note any UX follow-ups (overlays, prompts) in this file if they require human acknowledgement.

4. **If the backend crashes or needs to restart:**
   - Re-select the workspace in the UI.
   - Check the Xcode console for `💥 Backend terminated` logs before continuing.

5. **When updating dependencies or build scripts:**
   - Run relevant `npm install`, `pod install`, etc., then commit the lockfiles.
   - Mention the command in the commit message or PR description for traceability.

Keep this document up to date as the workflow evolves.

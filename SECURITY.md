# Security policy

Jeremias is a local-only, preview-stage Windows utility. There is no guaranteed support window yet.

Report vulnerabilities privately via GitHub private vulnerability reporting if enabled, or use the maintainer's public contact channel to request a private conversation. Do not post exploit details, personal window titles, credentials or sensitive screenshots in public issues.

The application must not read chat contents, process memory, browser data or credentials. It must not install services, require administrator access, alter system time or globally change PowerShell execution policy. Native pet docking may inspect limited window metadata and reposition only an explicitly linked eligible overlay. Fullscreen detection reads foreground-window geometry. The current local settings can contain a linked pet's process/class/title signature; do not share them unredacted.

The startup shortcut is opt-in. The launcher uses process-scoped ExecutionPolicy Bypass; this is not a sandbox or a security guarantee. Review scripts and assets before running. No code signing is provided in this preview.

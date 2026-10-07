# Safety

- The plugin never writes to the source buffer.
- Selected text is sent over the process's standard input rather than exposed
  in shell commands or process arguments.
- Every backend runs from a private, empty temporary working directory.
- Claude runs in safe mode with no tools and without session persistence.
- Codex runs ephemerally in its read-only sandbox without user configuration
  or repository rules.
- OpenCode receives inline configuration that denies all tools, disables
  external plugins, and disables sharing and snapshots. It runs with
  `--standalone` so the inline configuration is honored by the private server
  rather than ignored by the shared background service.
- Agy runs with `--sandbox` and without `--dangerously-skip-permissions`, so
  tool calls are refused by default.
- Backend failures and malformed output are displayed in the output buffer.

The selected text is sent to the configured AI provider and remains subject to
that provider's privacy policy and account limits. The CLIs may retain local
usage metadata or sessions according to their own storage policies; in
particular, OpenCode currently has no ephemeral `run` option.

Codex CLI does not expose a no-tools mode. Its read-only sandbox prevents file
changes, and the plugin isolates its working directory and ignores user and
repository instructions, but the model can still request read-only shell or
filesystem operations. Do not send untrusted or sensitive text through the
Codex backend if that residual access is unacceptable.

Agy CLI's default tool refusal is a policy-level "soft deny": the CLI refuses
the tool call and exits normally, but the model can still attempt one, and no
documented environment variable forces it to ignore a local
`~/.gemini/antigravity-cli/settings.json` that grants broader permissions. If
your machine's Agy configuration allows tools, that configuration takes
precedence over the plugin's flags. Review your Agy permission settings before
relying on this backend for untrusted or sensitive text.

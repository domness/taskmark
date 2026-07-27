# Repeated-Attempts Log

Read this file before suggesting an approach similar to a previous multi-attempt failure. Add an entry when an approach takes more than 2 attempts to work.

## 2026-07-27: Vault Initialization Failure Recovery

- What did not work: The first rollback removed `.localtodo` recursively after a failed manifest write. The next version made manifest creation exclusive but still used recursive removal for temporary-file cleanup and checked directory emptiness only before setup.
- What worked instead: Publish the manifest with `renameatx_np` and `RENAME_EXCL`, clean temporary files with POSIX `unlink`, remove rollback directories with POSIX `rmdir`, revalidate directory contents immediately before publication, and map a concurrent manifest to an actionable domain error.
- Note for next time: For filesystem transactions, review every cleanup path for recursive deletion and every check-then-write sequence for races. Add injected-failure and concurrent-change tests before considering the path complete.

## 2026-07-27: Autosave And History Race Hardening

- What did not work: Initial autosave and undo implementations treated refresh, selection, and mutation work as mostly independent. Repeated review found stale refresh publication, autosave/history races, and undo operations that could advance the native stack before acquiring their filesystem mutation path.
- What worked instead: Track vault sessions and model epochs, serialize mutations per path, merge successful writes immediately into the snapshot, keep drafts in the workspace model, and reserve history mutation paths before asynchronous filesystem work begins.
- Note for next time: Design asynchronous UI mutations as state machines before adding convenience behavior. Reserve shared resources synchronously, make stale-result rejection explicit, and add delayed-store race tests alongside happy-path tests.

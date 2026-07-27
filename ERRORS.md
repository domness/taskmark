# Repeated-Attempts Log

Read this file before suggesting an approach similar to a previous multi-attempt failure. Add an entry when an approach takes more than 2 attempts to work.

## 2026-07-27: Vault Initialization Failure Recovery

- What did not work: The first rollback removed `.localtodo` recursively after a failed manifest write. The next version made manifest creation exclusive but still used recursive removal for temporary-file cleanup and checked directory emptiness only before setup.
- What worked instead: Publish the manifest with `renameatx_np` and `RENAME_EXCL`, clean temporary files with POSIX `unlink`, remove rollback directories with POSIX `rmdir`, revalidate directory contents immediately before publication, and map a concurrent manifest to an actionable domain error.
- Note for next time: For filesystem transactions, review every cleanup path for recursive deletion and every check-then-write sequence for races. Add injected-failure and concurrent-change tests before considering the path complete.

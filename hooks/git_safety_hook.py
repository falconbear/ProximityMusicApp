#!/usr/bin/env python3
"""
git_safety_hook.py — PreToolUse Bash

危険な git / gh 操作を機械的にブロックする。container + `--dangerously-skip-permissions`
運用時の最終防衛線 (GH_TOKEN 経由の外部副作用を封じる)。

git block:
  - git push (to main/master/production/release)
  - git push --force (to protected branches)
  - git commit --no-verify (hooks bypass)
  - git commit --no-gpg-sign (signing bypass)
  - git rebase -i              (interactive, requires user)
  - git push --delete <branch> (branch deletion)

git warn:
  - git reset --hard <ref>
  - git branch -D <branch>
  - git commit --amend

gh block (GitHub API 経由の外部破壊を防ぐ):
  - gh repo delete
  - gh repo archive
  - gh repo rename
  - gh api -X DELETE / --method DELETE / -X PATCH (destructive REST ops)
  - gh issue delete
  - gh release delete
  - gh secret remove / gh secret set  (credential surface)
  - gh auth logout / gh auth setup-git  (auth mutation)
  - gh ssh-key delete
  - gh gpg-key delete

allow:
  - git push origin <feature-branch>
  - git push --force origin <feature-branch> (rebase scenarios on own branch)
  - 全ての read-only git / gh 操作
  - gh issue create, gh pr create, gh pr comment, gh pr ready, gh pr edit, etc

入力: Claude Code が PreToolUse hook で stdin に JSON を渡す
出力: block 時は exit code 2 + stderr で理由
"""

from __future__ import annotations

import json
import re
import shlex
import sys
import subprocess


def get_current_branch() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=2,
        )
        return out.stdout.strip()
    except Exception:
        return ""


def is_protected_branch(branch: str) -> bool:
    return branch in {"main", "master", "production", "release"}


def check_push(args: list[str]) -> str | None:
    """Return error message if push is unsafe, else None."""
    has_force = any(a in {"--force", "-f"} for a in args)
    has_force_with_lease = any(
        a == "--force-with-lease" or a.startswith("--force-with-lease=") for a in args
    )
    has_delete = any(a in {"--delete", "-d"} for a in args)

    # Determine target branch
    target_branch = ""
    # `git push <remote> <branch>` or `git push <remote> HEAD:<branch>` or
    # `git push origin <branch>:<remote-branch>`
    positional = [a for a in args if not a.startswith("-")]
    # positional[0] is "push", positional[1] is remote (or branch if 1 arg)
    if len(positional) >= 3:
        ref_spec = positional[2]
        if ":" in ref_spec:
            target_branch = ref_spec.split(":", 1)[1]
        else:
            target_branch = ref_spec
    else:
        target_branch = get_current_branch()

    # 1. Branch protection
    if is_protected_branch(target_branch):
        if has_force:
            return f"git push --force to protected branch '{target_branch}' is forbidden."
        return (
            f"direct push to protected branch '{target_branch}' is forbidden. "
            f"Open a Pull Request via gh CLI instead "
            f"(github-publishing skill, mode create-draft / update / ready)."
        )

    # 2. --delete is only safe on feature branches
    if has_delete:
        return (
            f"branch deletion via 'git push --delete' is risky. "
            f"Confirm with the user before deleting remote branches."
        )

    # 3. --force on non-protected feature branch is OK (rebase workflow)
    return None


def check_commit(args: list[str]) -> str | None:
    if "--no-verify" in args or "-n" in args:
        return (
            "git commit --no-verify is forbidden. Hooks exist to enforce "
            "test-integrity, contract-immutability, and TDD order. "
            "Fix the underlying issue rather than bypassing the gate."
        )
    if "--no-gpg-sign" in args:
        return (
            "git commit --no-gpg-sign bypasses GPG signing. "
            "Only allowed when the user has explicitly disabled signing."
        )
    if "--amend" in args:
        # Amend can be legitimate, only warn
        sys.stderr.write(
            "⚠ git commit --amend rewrites the previous commit. "
            "If that commit is already pushed, you'll need --force-with-lease. "
            "Confirm intent before proceeding.\n"
        )
    return None


def check_reset(args: list[str]) -> str | None:
    if "--hard" in args:
        # Warn only — sometimes needed
        sys.stderr.write(
            "⚠ git reset --hard discards working tree changes irreversibly. "
            "If you have uncommitted work, stash it first (`git stash`).\n"
        )
    return None


def check_rebase(args: list[str]) -> str | None:
    if "-i" in args or "--interactive" in args:
        return (
            "git rebase -i requires interactive input which Claude Code cannot provide. "
            "Use a non-interactive rebase or ask the user to run it manually."
        )
    return None


def parse_git_command(cmd: str) -> tuple[str, list[str]] | None:
    """Extract subcommand + args from a Bash command string. Returns None if not git."""
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        return None
    # Find the first 'git' token (handle 'cd foo && git ...', 'rtk git ...', etc)
    for i, t in enumerate(tokens):
        if t == "git" or t.endswith("/git"):
            after = tokens[i + 1 :]
            if not after:
                return None
            sub = after[0]
            return sub, after[1:]
    return None


def parse_gh_command(cmd: str) -> tuple[list[str], list[str]] | None:
    """Extract (subcommand chain, remaining args) from a Bash command string.

    Chain = contiguous non-flag tokens from the start until the first flag.
    Rest  = everything from the first flag onward.

    'gh repo delete foo --yes' -> (['repo', 'delete', 'foo'], ['--yes'])
    'gh api -X DELETE /repos/x/y' -> (['api'], ['-X', 'DELETE', '/repos/x/y'])
    """
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        return None
    for i, t in enumerate(tokens):
        if t == "gh" or t.endswith("/gh"):
            after = tokens[i + 1 :]
            if not after:
                return None
            chain: list[str] = []
            rest: list[str] = []
            in_chain = True
            for tok in after:
                if in_chain and not tok.startswith("-"):
                    chain.append(tok)
                else:
                    in_chain = False
                    rest.append(tok)
            if not chain:
                return None
            return chain, rest
    return None


# gh subcommand chains that are always destructive
GH_DESTRUCTIVE_CHAINS = [
    ("repo", "delete"),
    ("repo", "archive"),
    ("repo", "rename"),
    ("issue", "delete"),
    ("release", "delete"),
    ("secret", "remove"),
    ("secret", "delete"),
    ("secret", "set"),       # writes credentials; surface hardening
    ("auth", "logout"),
    ("auth", "setup-git"),
    ("ssh-key", "delete"),
    ("gpg-key", "delete"),
    ("variable", "delete"),
    ("variable", "remove"),
    ("codespace", "delete"),
    ("cache", "delete"),
]


def check_gh(chain: list[str], rest: list[str]) -> str | None:
    """Return error message if the gh command is destructive, else None."""
    # Destructive subcommand chain check
    for dest_chain in GH_DESTRUCTIVE_CHAINS:
        if tuple(chain[: len(dest_chain)]) == dest_chain:
            return (
                f"gh {' '.join(dest_chain)} is a destructive GitHub operation. "
                f"Confirm with the user before running it. "
                f"If this is intentional, run it manually outside of Claude Code."
            )

    # gh api with destructive method
    if chain and chain[0] == "api":
        method = None
        for i, tok in enumerate(rest):
            if tok in ("-X", "--method") and i + 1 < len(rest):
                method = rest[i + 1].upper()
                break
            if tok.startswith("--method="):
                method = tok.split("=", 1)[1].upper()
                break
        if method in ("DELETE", "PATCH", "PUT"):
            return (
                f"gh api -X {method} is a mutating REST call to GitHub. "
                f"Confirm with the user before running it manually outside of Claude Code."
            )

    return None


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    if payload.get("tool_name") != "Bash":
        sys.exit(0)

    cmd = payload.get("tool_input", {}).get("command", "")
    if not cmd:
        sys.exit(0)

    error: str | None = None

    # git check
    parsed = parse_git_command(cmd)
    if parsed is not None:
        sub, args = parsed
        if sub == "push":
            error = check_push(["push"] + args)
        elif sub == "commit":
            error = check_commit(args)
        elif sub == "reset":
            error = check_reset(args)
        elif sub == "rebase":
            error = check_rebase(args)
        elif sub == "branch" and "-D" in args:
            sys.stderr.write(
                "⚠ git branch -D force-deletes a local branch. "
                "Make sure no unmerged commits will be lost.\n"
            )

    # gh check (independent of git parse — a bash line may contain only gh)
    if error is None:
        gh_parsed = parse_gh_command(cmd)
        if gh_parsed is not None:
            chain, rest = gh_parsed
            error = check_gh(chain, rest)

    if error:
        sys.stderr.write(f"❌ git-safety: {error}\n")
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()

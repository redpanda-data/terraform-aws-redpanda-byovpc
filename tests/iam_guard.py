#!/usr/bin/env python3
"""Fail if the Redpanda agent's IAM policy lets it modify IAM it must not touch.

Reads the output of `terraform test -json -verbose` for tests/iam_guard.tftest.hcl (a file path, or
stdin) and, for every run, evaluates the policies attached to the agent role against each protected
role and policy:

  * every IAM role and policy this module creates, the agent's own included;
  * another deployment's module-owned role and policy (they carry the module-owned tag);
  * the rpk user role that Redpanda's bootstrap tooling creates outside this module.

An action on a protected resource is a violation when some Allow statement matches it and no Deny
statement provably does. The evaluation is conservative so that it can only err towards failing:
an Allow counts whatever its conditions, and a Deny counts only when it has no conditions or only
StringEquals/StringLike on aws:ResourceTag/<key> that the resource's tags satisfy.

--assume-allow-all adds an Allow of iam:* on *, so the run checks that the Deny statements alone
protect every resource. --drop-sid removes the statements with that Sid, to show a Deny is needed.

Exits 0 when there are no violations, 1 when there are, and 2 when the input can't be evaluated.
"""

import argparse
import fnmatch
import json
import re
import sys

AGENT_ROLE_ADDRESS = "aws_iam_role.redpanda_agent"

ROLE_WRITE_ACTIONS = [
    "iam:AttachRolePolicy",
    "iam:DeleteRole",
    "iam:DeleteRolePermissionsBoundary",
    "iam:DeleteRolePolicy",
    "iam:DetachRolePolicy",
    "iam:PutRolePermissionsBoundary",
    "iam:PutRolePolicy",
    "iam:TagRole",
    "iam:UntagRole",
    "iam:UpdateAssumeRolePolicy",
    "iam:UpdateRole",
    "iam:UpdateRoleDescription",
]
POLICY_WRITE_ACTIONS = [
    "iam:CreatePolicyVersion",
    "iam:DeletePolicy",
    "iam:DeletePolicyVersion",
    "iam:SetDefaultPolicyVersion",
    "iam:TagPolicy",
    "iam:UntagPolicy",
]

MODULE_OWNED_TAG = "redpanda-byovpc-module-owned"
IAM_ARN = re.compile(r"^arn:aws:iam::(\d{12}):(role|policy)/[\w+=,.@/-]+$")

# Resources outside this deployment's state. Their names match the module's naming so that a
# pattern broad enough to reach them is caught.
EXTERNAL_TARGETS = [
    ("role", "role/redpanda-agent-20261102000000000000000099", {MODULE_OWNED_TAG: "true"},
     "another deployment's agent role"),
    ("policy", "policy/redpanda-agent-1-20261102000000000000000099", {MODULE_OWNED_TAG: "true"},
     "another deployment's agent policy"),
    ("role", "role/redpanda-rpk-user-role-20261102000000000000000099", {},
     "rpk user role created by Redpanda's bootstrap tooling"),
]

ALLOW_ALL = {"sid": "AssumedAllowAll", "doc": "--assume-allow-all", "effect": "Allow",
             "actions": ["iam:*"], "not_actions": None, "resources": ["*"],
             "not_resources": None, "condition": []}


class GuardError(Exception):
    pass


def wildcard_match(pattern, value, ignore_case=False):
    if ignore_case:
        pattern, value = pattern.lower(), value.lower()
    # IAM wildcards are * and ?; fnmatch also treats [...] as a class, which IAM does not.
    return fnmatch.fnmatchcase(value, pattern.replace("[", "[[]"))


def policy_variables_to_wildcards(pattern):
    return re.sub(r"\$\{[^}]*\}", "*", pattern)


def statement_matches(stmt, action, arn, for_deny):
    if stmt["actions"] is not None:
        if not any(wildcard_match(a, action, ignore_case=True) for a in stmt["actions"]):
            return False
    elif stmt["not_actions"] is not None:
        if any(wildcard_match(a, action, ignore_case=True) for a in stmt["not_actions"]):
            return False
    else:
        return not for_deny

    patterns = stmt["resources"] if stmt["resources"] is not None else stmt["not_resources"]
    if patterns is None:
        return not for_deny
    if for_deny and any("${" in p for p in patterns):
        return False
    patterns = [policy_variables_to_wildcards(p) for p in patterns]
    matched = any(wildcard_match(p, arn) for p in patterns)
    return matched if stmt["resources"] is not None else not matched


def deny_conditions_hold(stmt, tags):
    for cond in stmt["condition"]:
        variable = cond["variable"]
        if cond["test"] not in ("StringEquals", "StringLike") or not variable.startswith("aws:ResourceTag/"):
            return False
        value = tags.get(variable[len("aws:ResourceTag/"):])
        if value is None:
            return False
        if cond["test"] == "StringEquals" and value not in cond["values"]:
            return False
        if cond["test"] == "StringLike" and not any(wildcard_match(v, value) for v in cond["values"]):
            return False
    return True


def resources_in(module):
    yield from module.get("resources", [])
    for child in module.get("child_modules", []):
        yield from resources_in(child)


def normalize(doc_address, stmt):
    return {
        "sid": stmt.get("sid") or "",
        "doc": doc_address,
        "effect": stmt.get("effect") or "Allow",
        # Unset lists come back as null or [] depending on the provider version.
        "actions": stmt.get("actions") or None,
        "not_actions": stmt.get("not_actions") or None,
        "resources": stmt.get("resources") or None,
        "not_resources": stmt.get("not_resources") or None,
        "condition": stmt.get("condition") or [],
    }


def agent_statements(resources):
    agent_role = resources.get(AGENT_ROLE_ADDRESS)
    if agent_role is None:
        raise GuardError(f"{AGENT_ROLE_ADDRESS} is not in the state")
    role_name = agent_role["values"]["name"]

    policies_by_arn = {r["values"]["arn"]: r for r in resources.values()
                       if r["mode"] == "managed" and r["type"] == "aws_iam_policy"}
    docs_by_json = {}
    for r in resources.values():
        if r["mode"] == "data" and r["type"] == "aws_iam_policy_document":
            docs_by_json.setdefault(r["values"]["json"], []).append(r)

    policy_texts = []
    for r in resources.values():
        values = r["values"]
        if r["type"] == "aws_iam_role_policy_attachment" and values["role"] == role_name:
            arn = values["policy_arn"]
            if arn not in policies_by_arn:
                raise GuardError(f"{r['address']} attaches {arn}, which this module does not create, "
                                 "so its statements cannot be checked")
            policy = policies_by_arn[arn]
            policy_texts.append((policy["address"], policy["values"]["policy"]))
        elif r["type"] == "aws_iam_role_policy" and values["role"] == role_name:
            policy_texts.append((r["address"], values["policy"]))
        elif r["type"] == "aws_iam_role" and r["address"] == AGENT_ROLE_ADDRESS:
            if values.get("managed_policy_arns") or values.get("inline_policy"):
                raise GuardError(f"{AGENT_ROLE_ADDRESS} has policies set on the role itself; "
                                 "attach them with aws_iam_role_policy_attachment instead")

    if not policy_texts:
        raise GuardError("no policies are attached to the agent role")

    statements = []
    for address, text in policy_texts:
        docs = docs_by_json.get(text, [])
        if len(docs) != 1:
            raise GuardError(
                f"cannot tell which aws_iam_policy_document {address} comes from ({len(docs)} "
                "documents share its placeholder JSON). Give the document an override_data with "
                "a unique Id in tests/iam_guard.tftest.hcl.")
        doc = docs[0]
        for stmt in doc["values"].get("statement") or []:
            statements.append(normalize(doc["address"], stmt))
    return [address for address, _ in policy_texts], statements


def protected_targets(resources):
    targets = []
    account_ids = set()
    for r in resources.values():
        if r["mode"] != "managed" or r["type"] not in ("aws_iam_role", "aws_iam_policy"):
            continue
        arn = r["values"]["arn"]
        m = IAM_ARN.match(arn or "")
        if not m or "NOT-OVERRIDDEN" in arn:
            raise GuardError(f"{r['address']} has ARN {arn!r}. Override it in "
                             "tests/iam_guard.tftest.hcl with the ARN AWS would generate.")
        account_ids.add(m.group(1))
        targets.append((m.group(2), arn, r["values"].get("tags") or {}, r["address"]))
    if len(account_ids) != 1:
        raise GuardError(f"module IAM ARNs span accounts {sorted(account_ids)}")
    account_id = account_ids.pop()
    for kind, path, tags, label in EXTERNAL_TARGETS:
        targets.append((kind, f"arn:aws:iam::{account_id}:{path}", tags, label))
    return targets


def evaluate(state, assume_allow_all, drop_sids):
    resources = {r["address"]: r for r in resources_in(state["root_module"])}
    # First, so a missing ARN override is reported as such rather than as a lookup failure.
    targets = protected_targets(resources)
    policy_addresses, statements = agent_statements(resources)
    statements = [s for s in statements if s["sid"] not in drop_sids]
    if assume_allow_all:
        statements.append(ALLOW_ALL)
    if not any(arn == resources[AGENT_ROLE_ADDRESS]["values"]["arn"] for _, arn, _, _ in targets):
        raise GuardError("the agent role is not among the protected targets")

    allows = [s for s in statements if s["effect"] == "Allow"]
    denies = [s for s in statements if s["effect"] == "Deny"]
    violations = []
    checks = 0
    for kind, arn, tags, label in targets:
        for action in ROLE_WRITE_ACTIONS if kind == "role" else POLICY_WRITE_ACTIONS:
            checks += 1
            allowing = [s for s in allows if statement_matches(s, action, arn, for_deny=False)]
            if not allowing:
                continue
            if any(statement_matches(s, action, arn, for_deny=True) and deny_conditions_hold(s, tags)
                   for s in denies):
                continue
            violations.append((action, arn, label, allowing))
    return policy_addresses, len(statements), checks, violations


def states_from(lines):
    states, failed_runs, errors = {}, [], []
    for line in lines:
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        if msg.get("type") == "test_state":
            states[msg["@testrun"]] = msg["test_state"]
        elif msg.get("type") == "test_run" and msg["test_run"].get("status") not in (None, "pass"):
            failed_runs.append(f"{msg['@testrun']}: {msg['test_run']['status']}")
        elif msg.get("type") == "diagnostic" and msg["diagnostic"].get("severity") == "error":
            d = msg["diagnostic"]
            errors.append(f"{d.get('summary', '')}: {d.get('detail', '')}")
    return states, failed_runs, errors


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input", nargs="?", help="terraform test -json -verbose output (default: stdin)")
    parser.add_argument("--assume-allow-all", action="store_true",
                        help="add an Allow of iam:* on *, so only the Deny statements protect resources")
    parser.add_argument("--drop-sid", action="append", default=[],
                        help="remove statements with this Sid before evaluating (repeatable)")
    args = parser.parse_args()

    with (open(args.input) if args.input else sys.stdin) as f:
        states, failed_runs, errors = states_from(f)
    if failed_runs or errors:
        print("terraform test runs did not pass: " + ", ".join(failed_runs), file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        return 2
    if not states:
        print("no test_state in the input; run `terraform test -json -verbose` with "
              "tests/iam_guard.tftest.hcl", file=sys.stderr)
        return 2

    errored = violated = False
    for run, state in states.items():
        try:
            policies, n_statements, checks, violations = evaluate(state, args.assume_allow_all, set(args.drop_sid))
        except GuardError as e:
            print(f"[{run}] ERROR: {e}", file=sys.stderr)
            errored = True
            continue
        print(f"[{run}] {len(policies)} agent policies, {n_statements} statements, {checks} checks, "
              f"{len(violations)} violations")
        for action, arn, label, allowing in violations:
            violated = True
            via = ", ".join(f"{s['doc']} {s['sid'] or '(no Sid)'}" for s in allowing)
            print(f"  VIOLATION {action} on {arn} ({label}): allowed by {via} and not denied")
    return 2 if errored else 1 if violated else 0


if __name__ == "__main__":
    sys.exit(main())

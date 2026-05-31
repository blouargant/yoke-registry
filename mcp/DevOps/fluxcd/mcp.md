---
name: flux-operator-mcp
description: >
  Flux Operator MCP server — connects Claude to live Kubernetes clusters running Flux CD, exposing
  read-only reporting, reconciliation, suspend/resume, server-side apply/delete, multi-cluster
  context switching, and Flux documentation search. Use to debug Flux installations, inspect
  resource status and logs, trigger reconciliations, and audit GitOps deployments on a cluster.
command: /path/to/flux-operator-mcp
args:
  - serve
env:
  KUBECONFIG: /path/to/.kube/config
skills:
  - gitops-knowledge
  - gitops-cluster-debug
  - gitops-repo-audit
---

# Flux Operator MCP Server

The Flux Operator MCP server connects AI assistants to Kubernetes clusters running Flux CD,
enabling natural-language interaction with live GitOps resources. It is published by
ControlPlane as part of the [flux-operator](https://github.com/controlplaneio-fluxcd/flux-operator)
project. Claude can inspect Flux installations, read resource status and pod logs, trigger
reconciliations, apply or delete manifests, switch between clusters, and search the official
Flux documentation.

## What it provides

| Category | Tools |
|----------|-------|
| Reporting (read) | `get_flux_instance`, `get_kubernetes_resources`, `get_kubernetes_logs`, `get_kubernetes_metrics`, `get_kubernetes_api_versions` |
| Multi-cluster | `get_kubeconfig_contexts`, `set_kubeconfig_context` |
| Reconciliation | `reconcile_flux_resourceset`, `reconcile_flux_source`, `reconcile_flux_kustomization`, `reconcile_flux_helmrelease` |
| Suspend / Resume | `suspend_flux_reconciliation`, `resume_flux_reconciliation` |
| Resource management | `apply_kubernetes_manifest`, `delete_kubernetes_resource`, `install_flux_instance` |
| Documentation | `search_flux_docs` |

Full tool reference: [fluxoperator.dev/docs/mcp/tools](https://fluxoperator.dev/docs/mcp/tools/).

## Setup

Install the binary with Homebrew, or download the AMD64/ARM64 binary from the
[releases page](https://github.com/controlplaneio-fluxcd/flux-operator/releases) and place it on
your `PATH`:

```bash
brew install controlplaneio-fluxcd/tap/flux-operator-mcp
```

Update `command` in `mcp.json` to the absolute path of the `flux-operator-mcp` binary and point
`KUBECONFIG` at the kubeconfig for the cluster you want to manage. The server uses **stdio**
transport by default, which is compatible with most MCP hosts.

```bash
flux-operator-mcp serve
```

## Serve flags

| Flag | Purpose | Default |
|------|---------|---------|
| `--transport` | Transport protocol: `stdio`, `sse`, or `http` | `stdio` |
| `--port` | Listen port for `sse`/`http` transports | `8080` |
| `--read-only` | Disable cluster-modifying tools (reconcile, suspend, resume, apply, delete, install) | `false` |
| `--mask-secrets` | Obscure sensitive values in tool output | `true` |
| `--kube-as` | Impersonate a service account | none |

> **Safety:** for auditing or debugging untrusted clusters, run with `--read-only` so only the
> reporting and documentation tools are exposed. `--mask-secrets` is on by default and should stay
> enabled unless you explicitly need secret values.

## Web transports

For hosts that prefer HTTP, start the server with a web transport instead of stdio:

```bash
flux-operator-mcp serve --transport http --port 8080   # Streamable HTTP
flux-operator-mcp serve --transport sse  --port 8080   # legacy Server-Sent Events
```

# Kubernetes Remediation Runbook

Detailed, gated fixes for common failures. Read the section matching the
category from `k8s-triage`. Every **⚠ gated** step needs explicit user
confirmation for *that specific action*. Placeholders: `<ns>` namespace,
`<pod>`/`<name>` resource, `<node>` node. Always confirm the cluster context
first (`kubectl config current-context`).

---

## Pod stuck Terminating

A pod sticks in `Terminating` when its grace period can't complete: a
finalizer is blocking, the kubelet on its node is unreachable, or a process
ignores SIGTERM.

1. **Find out why.** `kubectl describe pod <pod> -n <ns>` and
   `kubectl get pod <pod> -n <ns> -o yaml | grep -A5 finalizers`.
2. **Check the node.** `kubectl get node <node-of-pod>`. If the node is
   `NotReady`/gone, the pod can't drain — see *Node NotReady* first.
3. **If a finalizer blocks it** and the controller that owns the finalizer is
   gone: ⚠ gated — remove the finalizer:
   ```bash
   kubectl patch pod <pod> -n <ns> -p '{"metadata":{"finalizers":null}}' --type=merge
   ```
4. **Force delete** — ⚠ gated, last resort. ONLY when the node is confirmed
   dead/unrecoverable (a force-delete while the node still runs the container
   can double-run a stateful pod and corrupt data):
   ```bash
   kubectl delete pod <pod> -n <ns> --grace-period=0 --force
   ```
   For StatefulSet pods, confirm the workload tolerates this before forcing.

---

## Pod Pending / Unschedulable

1. **Read the scheduler's reason.**
   `kubectl describe pod <pod> -n <ns>` → Events (look for `FailedScheduling`).
2. **Common causes & fixes:**
   - *Insufficient cpu/memory*: `kubectl describe nodes | grep -A5 Allocated`.
     Lower the pod's requests, add capacity, or scale a node group.
   - *Unbound PVC*: pod waits on storage → see *Storage (PVC/PV)*.
   - *Taints*: `kubectl describe node <node> | grep Taints`. Add a matching
     toleration to the pod spec, or ⚠ gated remove the taint
     (`kubectl taint nodes <node> <key>-`).
   - *Affinity/selector mismatch*: relax `nodeSelector`/`affinity`, or label
     a node `kubectl label node <node> <key>=<val>`.
3. Apply the smallest spec change (edit the Deployment, not the Pod — Pods are
   recreated by the controller) and re-check `kubectl get pod -w`.

---

## CrashLoopBackOff

1. **Get the crash reason.**
   `kubectl logs <pod> -n <ns> --previous --tail=200` and
   `kubectl describe pod <pod> -n <ns>` (exit code, last state). If logs are
   large, switch to `k8s-log-investigation`.
2. **Classify:**
   - *Exit 0/1 app error*: fix config/env/secret/image — edit the Deployment.
   - *Failing liveness probe* (restart loop with healthy app): the probe is
     too tight. Widen `initialDelaySeconds`/`timeoutSeconds`/`failureThreshold`
     in the Deployment.
   - *Missing config/secret*: `kubectl get cm,secret -n <ns>`; create or fix
     the referenced object.
   - *OOM* (exit 137): see *OOMKilled*.
3. **To inspect without the loop** — ⚠ gated, temporary: run a debug copy.
   The trailing `-- sh` overrides `<c>`'s command in the *copy* so it starts a
   shell instead of re-crashing; the original pod is untouched:
   ```bash
   kubectl debug <pod> -n <ns> -it --copy-to=<pod>-debug --container=<c> -- sh
   ```
   If the crash is at the image entrypoint, also swap the image with
   `--set-image=<c>=<known-good-image>`. Delete the debug copy when done:
   `kubectl delete pod <pod>-debug -n <ns>`.

---

## Image pull failures

`ImagePullBackOff` / `ErrImagePull`.

1. `kubectl describe pod <pod> -n <ns>` → exact pull error.
2. **Fixes by cause:**
   - *Wrong tag/repo*: correct `image:` in the Deployment.
   - *Private registry, no creds*: create/repair the pull secret and reference
     it:
     ```bash
     kubectl create secret docker-registry regcred -n <ns> \
       --docker-server=<reg> --docker-username=<u> --docker-password=<pw>
     # then add imagePullSecrets: [{name: regcred}] to the pod spec
     ```
   - *Rate-limited / unreachable registry*: confirm node egress; retry after
     backoff; consider a pull-through cache.

---

## OOMKilled

1. Confirm: `kubectl describe pod <pod> -n <ns>` shows `Reason: OOMKilled`
   (exit 137).
2. **Raise the limit** (edit the Deployment) if the workload legitimately
   needs more, **or** fix the leak in the app. Set `resources.limits.memory`
   and a matching `requests.memory`.
3. Watch real usage: `kubectl top pod <pod> -n <ns>` (needs metrics-server).
4. Avoid setting limits far above node capacity — that just moves the failure
   to scheduling or node pressure.

---

## Evicted pods

Eviction = node disk/memory/PID pressure.

1. `kubectl get pods -n <ns> --field-selector=status.phase=Failed` and
   `kubectl describe node <node> | grep -i pressure`.
2. **Clean up evicted pods** — ⚠ gated (they're already dead, but confirm).
   Scope the delete to one namespace so it stays in sync with the listing:
   ```bash
   kubectl delete pods -n <ns> --field-selector=status.phase=Failed
   ```
   To sweep every namespace, replace `-n <ns>` with `-A` (do not mix the two —
   `-A` lists across namespaces while `-n` pins one, which mismatches).
3. **Remove the pressure source**: free disk on the node (image/log GC), lower
   per-pod requests, or add capacity. If one node repeatedly evicts, see
   *Node NotReady* / drain it for inspection.

---

## Service / endpoints

Service exists but nothing answers.

1. `kubectl get endpoints <svc> -n <ns>` (or `endpointslices`). Empty = no
   ready backing pods.
2. **Selector mismatch**: compare `kubectl get svc <svc> -o yaml` selector
   against pod labels (`kubectl get pods -n <ns> --show-labels`). Fix the
   selector or the labels.
3. **Pods not Ready**: readiness probe failing keeps them out of endpoints →
   fix the probe (see *CrashLoopBackOff*).
4. **Port mismatch**: `targetPort` must match the container's port.
5. Test from inside: ⚠ gated debug pod
   `kubectl run nettest --rm -it --image=nicolaka/netshoot -n <ns> -- sh`.

---

## Stuck rollout

Deployment not progressing / stuck.

1. `kubectl rollout status deploy/<name> -n <ns>` and
   `kubectl rollout history deploy/<name> -n <ns>`.
2. **New pods crash/never Ready**: fix the new version (see CrashLoop / image).
3. **Roll back** — ⚠ gated:
   `kubectl rollout undo deploy/<name> -n <ns> [--to-revision=<n>]`.
4. **Paused rollout**: `kubectl rollout resume deploy/<name> -n <ns>`.
5. **`maxUnavailable`/`maxSurge` too strict** with limited capacity: relax the
   strategy in the Deployment.

---

## Namespace stuck Terminating

A namespace hangs in `Terminating` when a resource in it still has a finalizer
or an aggregated API behind it is down.

1. **Find what remains:**
   ```bash
   kubectl api-resources --verbs=list --namespaced -o name \
     | xargs -n1 kubectl get --show-kind --ignore-not-found -n <ns>
   ```
2. **Failed aggregated API?** `kubectl get apiservice | grep -v True` — a
   broken `APIService` blocks namespace cleanup; fix/remove it.
3. **Remove the blocking resource's finalizer** (preferred over forcing the
   namespace) — ⚠ gated:
   `kubectl patch <res> <name> -n <ns> -p '{"metadata":{"finalizers":null}}' --type=merge`.
4. **Force-clear the namespace finalizer** — ⚠ gated, last resort (leaves
   orphaned resources if done prematurely):
   ```bash
   kubectl get ns <ns> -o json \
     | jq 'del(.spec.finalizers)' \
     | kubectl replace --raw "/api/v1/namespaces/<ns>/finalize" -f -
   ```

---

## Storage (PVC/PV)

**PVC stuck Pending:**
1. `kubectl describe pvc <pvc> -n <ns>` → Events.
2. *No matching PV / no provisioner*: confirm the `storageClassName` exists
   (`kubectl get sc`) and its provisioner is healthy. Fix the class name or
   install/repair the CSI driver.
3. *Access mode / size* unsatisfiable: align the claim with available PVs.

**PVC/PV stuck Terminating:**
1. A bound PVC won't delete while a pod uses it — delete the consumer first.
2. ⚠ gated finalizer removal when the backing volume is already gone:
   `kubectl patch pv <pv> -p '{"metadata":{"finalizers":null}}' --type=merge`
   (same for the PVC). Confirm no live workload still needs the data.
3. Check `persistentVolumeReclaimPolicy` before deleting a PV (`Delete` may
   destroy real cloud storage).

---

## Stuck finalizers (generic)

Any custom resource (CR) that won't delete:
1. `kubectl get <res> <name> -n <ns> -o yaml | grep -A5 finalizers`.
2. The owning controller/operator should clear the finalizer. If it's gone or
   broken, ⚠ gated manual removal:
   `kubectl patch <res> <name> -n <ns> -p '{"metadata":{"finalizers":null}}' --type=merge`.
3. Removing a finalizer skips the operator's cleanup — confirm external
   resources (cloud objects, etc.) are handled separately.

---

## Node NotReady

1. `kubectl describe node <node>` → Conditions + Events. Check
   `kubectl get pods -n kube-system -o wide --field-selector spec.nodeName=<node>`.
2. **Common causes**: kubelet down (see *Control plane: kubelet*), disk/memory
   pressure (free space, see *Evicted pods*), network/CNI plugin down, or the
   node VM is gone.
3. **Cordon to stop new scheduling** while investigating — ⚠ gated:
   `kubectl cordon <node>`.
4. **If the node is permanently dead** — ⚠ gated: drain (see below) then
   `kubectl delete node <node>` (this only removes it from the API; reclaim
   the VM separately). Force-deleting its stuck pods may be needed.

---

## Draining a node

1. ⚠ gated:
   `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`.
2. **Blocked by a PodDisruptionBudget**: `kubectl get pdb -A`. Either wait for
   capacity so the PDB can be honoured, temporarily scale the workload up, or
   ⚠ gated relax/delete the PDB — never silently force past a PDB on a
   stateful/quorum workload.
3. After maintenance: `kubectl uncordon <node>`.

---

## CoreDNS

Cluster DNS resolution failing.

1. `kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide` — are CoreDNS
   pods Ready? `kubectl logs -n kube-system -l k8s-app=kube-dns`.
2. Test: ⚠ gated debug pod →
   `nslookup kubernetes.default` from a `netshoot`/`busybox` pod.
3. **Fixes**: restart CoreDNS (⚠ gated
   `kubectl rollout restart deploy/coredns -n kube-system`); check the
   `coredns` ConfigMap for a bad `forward`/upstream; ensure CoreDNS isn't
   OOMKilled (raise limits).

---

## Control plane: API server

Host-level — usually needs SSH to a control-plane node; hand commands to the
user when only `kubectl` is available.

1. From the node: `crictl ps | grep apiserver` (or
   `docker ps`), `journalctl -u kubelet -n 200`.
2. Static pod manifest lives at `/etc/kubernetes/manifests/kube-apiserver.yaml`
   — a syntax error there crashes it; validate before editing. ⚠ gated.
3. Confirm etcd is healthy first (apiserver can't start without it) — see
   below. Check certs aren't expired (see *certificates*).

---

## Control plane: etcd

Host-level / extremely sensitive. ⚠ gated for any mutation; **snapshot first**.

1. Health (run on an etcd node with the right certs):
   ```bash
   ETCDCTL_API=3 etcdctl endpoint health \
     --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key
   ```
2. **Out of space / `mvcc: database space exceeded`**: ⚠ gated — back up,
   then compact + defrag, then disarm the alarm. Get the current revision
   first (`<rev>` is the `Revision` field from
   `etcdctl endpoint status -w json` / `--write-out=table`), then:
   `etcdctl compact <rev>` → `etcdctl defrag` → `etcdctl alarm disarm`.
3. **Lost quorum**: do not improvise — restore from a known-good snapshot
   (`etcdctl snapshot restore`) following the cluster's runbook. Stop here and
   escalate unless the user explicitly owns this recovery.

---

## Control plane: kubelet

On the affected node (SSH):
1. `systemctl status kubelet` and `journalctl -u kubelet -n 200 --no-pager`.
2. **Common fixes** — ⚠ gated: `systemctl restart kubelet`; fix
   `/var/lib/kubelet/config.yaml` or `/etc/kubernetes/kubelet.conf` if
   misconfigured; ensure the container runtime (`crictl info`) is up; free
   disk if the node is under disk pressure.
3. After recovery confirm `kubectl get node <node>` returns `Ready`.

---

## Control plane: certificates

kubeadm clusters: expired certs make the apiserver/kubelet reject connections.
1. Check: `kubeadm certs check-expiration` (on a control-plane node).
2. ⚠ gated renew: `kubeadm certs renew all`, then restart the control-plane
   static pods (move manifests out/in of `/etc/kubernetes/manifests/`) and
   `systemctl restart kubelet`. Back up `/etc/kubernetes/pki` first.
3. Update any kubeconfig that embedded the old client cert.

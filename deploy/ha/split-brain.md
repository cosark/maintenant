# Resolving a DRBD split brain (`sqlite/drbd`)

A split brain happens when both nodes wrote to the replicated volume while they could not
see each other, usually after a double failure. The volume is configured so that DRBD
detects it on reconnection, drops the connection (`StandAlone`) and keeps both copies
intact (`after-sb-*pri disconnect`). om3 then refuses to promote the volume. Nothing ever
resolves it automatically (FR-025): resolving means discarding the writes of one side, and
only an operator decides that.

## 1. Recognise it

On the bench:

```sh
deploy/ha/lab/lab status
```

The verdict is `split` and a `storage` line names the side to keep:

```
storage    split brain: keep node-a (primary), discard node-b; resolve by hand with deploy/ha/split-brain.md
```

`lab status --json` carries the same judgement in `.storage` (`keep`, `discard`, `reason`).

Elsewhere, on each node:

```sh
drbdadm status maintenant
journalctl -k | grep -i 'split-brain'
```

A connection to the other node in `StandAlone`, and `Split-Brain detected` in the kernel
log, confirm it.

## 2. Freeze the service

So that om3 does not try to start or move it while you work:

```sh
om maintenant freeze
```

## 3. Choose the side to keep

`lab status` applies these rules in order; apply them by hand outside the bench, reading
`drbdsetup status --json --statistics maintenant` on both nodes:

| Rule | Reason shown | Why |
| ---- | ------------ | --- |
| Both nodes must report their volume | `incomplete` otherwise, no side named | the silent node may hold the newer writes |
| The only `Primary` | `primary` | the service runs there: its writes are the ones clients saw last |
| The only disk `UpToDate` | `only_up_to_date` | the other copy is already known to be stale |
| The larger `out-of-sync` toward the peer | `most_changes` | that side wrote more since the split |
| Otherwise | `tie`, no side named | compare the data before choosing |

When no side is named, look at the data itself: the most recent rows of the SQLite
database on each side tell which one served the clients last.

## 4. Optionally keep a copy of the side you discard

On the node to discard, with `<backing>` the disk DRBD sits on (`ha_drbd_backing_device`,
`/dev/vdb` on the bench):

```sh
drbdadm down maintenant
dd if=<backing> of=/root/maintenant-discarded.img bs=4M conv=fsync
drbdadm up maintenant
```

## 5. Discard one side

On the node to discard, stop the instance if it runs there (`om maintenant instance stop`),
then:

```sh
drbdadm secondary maintenant
drbdadm disconnect maintenant
drbdadm connect --discard-my-data maintenant
```

On the node to keep, only if its connection is still `StandAlone`:

```sh
drbdadm connect maintenant
```

On the arbitrator too: it also saw the split and left its connection to the discarded
node `StandAlone`, and that node never counts its quorum vote again until it reconnects:

```sh
drbdadm adjust maintenant
```

DRBD resynchronises the discarded node from the kept one. Wait until both disks are
`UpToDate` and the connection is `Connected`:

```sh
drbdadm status maintenant
```

## 6. Unfreeze

```sh
om maintenant unfreeze
```

On the bench, `lab status` must come back `green`, with the service on the kept node.

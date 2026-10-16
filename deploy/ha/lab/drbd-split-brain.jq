# Names the side of a DRBD split brain to keep, by the rules of deploy/ha/split-brain.md; never resolves it.
[.[] | select(.drbd != null)] as $nodes
| [$nodes[] | select(any(.drbd.connections[]?; .state == "StandAlone"))] as $split
| [$nodes[] | select(.drbd.role == "Primary" or .drbd.role == "Secondary")] as $known
| [$known[] | select(.drbd.role == "Primary")] as $primaries
| [$known[] | select(.drbd.disk == "UpToDate")] as $current
| [$known[] | {name, kib: ([.drbd.connections[] | select(.state == "StandAlone") | .out_of_sync_kib // 0] | add // 0)}]
  | sort_by(-.kib) as $changes
| if ($split | length) == 0 then
	{split_brain: false, keep: null, discard: [], reason: null}
  else
	(if ($known | length) < ($nodes | length) then {keep: null, reason: "incomplete"}
	 elif ($primaries | length) == 1 then {keep: $primaries[0].name, reason: "primary"}
	 elif ($current | length) == 1 then {keep: $current[0].name, reason: "only_up_to_date"}
	 elif ($changes | length) >= 2 and $changes[0].kib > $changes[1].kib then {keep: $changes[0].name, reason: "most_changes"}
	 else {keep: null, reason: "tie"}
	 end) as $d
	| {
		split_brain: true,
		keep: $d.keep,
		discard: (if $d.keep == null then [] else [$nodes[].name | select(. != $d.keep)] end),
		reason: $d.reason
	}
  end

#!/usr/bin/env bats

JUDGE="$BATS_TEST_DIRNAME/../drbd-split-brain.jq"

node() {
	# name role disk connection-state out-of-sync-kib
	jq -n --arg n "$1" --arg r "$2" --arg d "$3" --arg s "$4" --argjson k "$5" \
		'{name: $n, drbd: {role: $r, disk: $d, connections: [{peer: "peer", state: $s, peer_disk: "DUnknown", out_of_sync_kib: $k}]}}'
}

judge() {
	jq -s '.' | jq -c -f "$JUDGE"
}

@test "a connected volume is no split brain" {
	run judge < <(node node-a Primary UpToDate Connected 0; node node-b Secondary UpToDate Connected 0)
	[ "$output" = '{"split_brain":false,"keep":null,"discard":[],"reason":null}' ]
}

@test "other modes carry no volume" {
	run jq -c -f "$JUDGE" <<<'[{"name":"node-a","drbd":null},{"name":"node-b","drbd":null}]'
	[ "$output" = '{"split_brain":false,"keep":null,"discard":[],"reason":null}' ]
}

@test "the primary is kept" {
	run judge < <(node node-a Secondary UpToDate StandAlone 900; node node-b Primary UpToDate StandAlone 10)
	[ "$output" = '{"split_brain":true,"keep":"node-b","discard":["node-a"],"reason":"primary"}' ]
}

@test "without a primary, the only up-to-date copy is kept" {
	run judge < <(node node-a Secondary Outdated StandAlone 900; node node-b Secondary UpToDate StandAlone 10)
	[ "$output" = '{"split_brain":true,"keep":"node-b","discard":["node-a"],"reason":"only_up_to_date"}' ]
}

@test "two primaries: the side that changed most is kept" {
	run judge < <(node node-a Primary UpToDate StandAlone 900; node node-b Primary UpToDate StandAlone 10)
	[ "$output" = '{"split_brain":true,"keep":"node-a","discard":["node-b"],"reason":"most_changes"}' ]
}

@test "equal changes name no side" {
	run judge < <(node node-a Secondary UpToDate StandAlone 10; node node-b Secondary UpToDate StandAlone 10)
	[ "$output" = '{"split_brain":true,"keep":null,"discard":[],"reason":"tie"}' ]
}

@test "a node that does not report its volume names no side" {
	run judge < <(node node-a Primary UpToDate StandAlone 10; node node-b unknown "" Connecting 0)
	[ "$output" = '{"split_brain":true,"keep":null,"discard":[],"reason":"incomplete"}' ]
}

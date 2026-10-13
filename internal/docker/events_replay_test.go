// Copyright 2026 Benjamin Touchard (Kolapsis)
// SPDX-License-Identifier: Apache-2.0

package docker

import (
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestStreamEvents_FirstSubscriptionAfterConnectReplaysFromTheConnection(t *testing.T) {
	api := &scriptedEventsAPI{}
	c := &Client{cli: api, logger: slog.New(slog.NewTextHandler(io.Discard, nil))}

	ctx := t.Context()
	before := time.Now()
	require.NoError(t, c.TryConnect(ctx))
	after := time.Now()

	subscribed := func(n int) func() bool {
		return func() bool { return len(api.subscribedSince()) == n }
	}
	c.StreamEvents(ctx)
	require.Eventually(t, subscribed(1), 5*time.Second, 10*time.Millisecond)
	c.StreamEvents(ctx)
	require.Eventually(t, subscribed(2), 5*time.Second, 10*time.Millisecond)

	since := api.subscribedSince()
	replayFrom, err := time.Parse(time.RFC3339Nano, since[0])
	require.NoError(t, err)
	assert.WithinRange(t, replayFrom, before, after)
	assert.Empty(t, since[1], "a later subscription without a new connection starts live")
}

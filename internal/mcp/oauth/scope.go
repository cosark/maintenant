package oauth

// ParseScope normalises an OAuth scope request: empty or "read" yields "read", a set of read and write yields "read write", anything else is an error.
func ParseScope(raw string) (string, error) { panic("not implemented") }

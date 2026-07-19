//go:build tools

// Package dependencies anchors approved dependencies that land before their
// product-facing use. The tools tag keeps them out of the phase-1 CLI binary.
package dependencies

import _ "github.com/zalando/go-keyring"

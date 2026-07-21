package command

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
)

type operationKey struct {
	path  string
	value string
}

func acquireOperationKey(runtime Runtime, restart bool, parts ...string) (operationKey, error) {
	if runtime.Random == nil {
		return operationKey{}, errors.New("randomness unavailable")
	}
	root, ok := runtime.LookupEnv("SHORTBREAD_STATE_DIR")
	if !ok || strings.TrimSpace(root) == "" {
		cacheRoot, err := os.UserCacheDir()
		if err != nil {
			return operationKey{}, err
		}
		root = filepath.Join(cacheRoot, "shortbread", "operations")
	}
	if err := os.MkdirAll(root, 0o700); err != nil {
		return operationKey{}, err
	}
	identity := sha256.Sum256([]byte(strings.Join(parts, "\x00")))
	path := filepath.Join(root, hex.EncodeToString(identity[:])+".key")
	if restart {
		if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
			return operationKey{}, err
		}
	}
	if stored, err := os.ReadFile(path); err == nil {
		value := strings.TrimSpace(string(stored))
		if validOperationKey(value) {
			return operationKey{path: path, value: value}, nil
		}
		if err := os.Remove(path); err != nil {
			return operationKey{}, err
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return operationKey{}, err
	}

	var entropy [32]byte
	defer clear(entropy[:])
	if _, err := io.ReadFull(runtime.Random, entropy[:]); err != nil {
		return operationKey{}, err
	}
	value := base64.RawURLEncoding.EncodeToString(entropy[:])
	file, err := os.CreateTemp(root, ".operation-key-*")
	if err != nil {
		return operationKey{}, err
	}
	temporaryPath := file.Name()
	defer os.Remove(temporaryPath)
	if err := file.Chmod(0o600); err != nil {
		_ = file.Close()
		return operationKey{}, err
	}
	if _, err = file.WriteString(value + "\n"); err == nil {
		err = file.Sync()
	}
	closeErr := file.Close()
	if err != nil {
		return operationKey{}, err
	}
	if closeErr != nil {
		return operationKey{}, closeErr
	}
	if err := os.Link(temporaryPath, path); errors.Is(err, os.ErrExist) {
		stored, readErr := os.ReadFile(path)
		if readErr != nil || !validOperationKey(strings.TrimSpace(string(stored))) {
			return operationKey{}, errors.New("concurrent operation key unavailable")
		}
		return operationKey{path: path, value: strings.TrimSpace(string(stored))}, nil
	} else if err != nil {
		return operationKey{}, err
	}
	return operationKey{path: path, value: value}, nil
}

func (key operationKey) complete() error {
	if key.path == "" {
		return errors.New("operation key unavailable")
	}
	err := os.Remove(key.path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	return err
}

func validOperationKey(value string) bool {
	decoded, err := base64.RawURLEncoding.DecodeString(value)
	return err == nil && len(decoded) == 32
}

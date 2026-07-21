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

func acquireOperationKey(runtime Runtime, parts ...string) (operationKey, error) {
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
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if errors.Is(err, os.ErrExist) {
		return acquireOperationKey(runtime, parts...)
	}
	if err != nil {
		return operationKey{}, err
	}
	if _, err = file.WriteString(value + "\n"); err == nil {
		err = file.Sync()
	}
	closeErr := file.Close()
	if err != nil {
		_ = os.Remove(path)
		return operationKey{}, err
	}
	if closeErr != nil {
		_ = os.Remove(path)
		return operationKey{}, closeErr
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

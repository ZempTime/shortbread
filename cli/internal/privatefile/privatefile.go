package privatefile

import (
	"errors"
	"io"
	"os"
)

var (
	ErrReserve = errors.New("could not reserve private output file")
	ErrCommit  = errors.New("could not write private output file")
	ErrAbort   = errors.New("could not remove private output file")
)

type Reservation struct {
	path string
	file *os.File
	done bool
}

func Reserve(path string) (*Reservation, error) {
	if path == "" || path == "-" {
		return nil, ErrReserve
	}

	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return nil, ErrReserve
	}
	reservation := &Reservation{path: path, file: file}
	if err := file.Chmod(0o600); err != nil {
		_ = reservation.cleanup()
		return nil, ErrReserve
	}
	info, err := file.Stat()
	if err != nil || info.Mode().Perm() != 0o600 {
		_ = reservation.cleanup()
		return nil, ErrReserve
	}
	return reservation, nil
}

func (reservation *Reservation) Commit(content []byte) error {
	if reservation == nil || reservation.done || reservation.file == nil {
		return ErrCommit
	}
	if _, err := reservation.file.Write(content); err != nil {
		_ = reservation.cleanup()
		return ErrCommit
	}
	if err := reservation.file.Sync(); err != nil {
		_ = reservation.cleanup()
		return ErrCommit
	}
	if err := reservation.file.Close(); err != nil {
		_ = reservation.cleanup()
		return ErrCommit
	}
	reservation.done = true
	reservation.file = nil
	return nil
}

func (reservation *Reservation) Abort() error {
	if reservation == nil || reservation.done {
		return nil
	}
	if err := reservation.cleanup(); err != nil {
		return ErrAbort
	}
	return nil
}

func (reservation *Reservation) cleanup() error {
	var closeErr error
	if reservation.file != nil {
		closeErr = reservation.file.Close()
		reservation.file = nil
	}
	removeErr := os.Remove(reservation.path)
	removed := removeErr == nil || errors.Is(removeErr, os.ErrNotExist)
	reservation.done = removed
	if closeErr != nil || !removed {
		return io.ErrUnexpectedEOF
	}
	return nil
}

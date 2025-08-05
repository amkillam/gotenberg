package api

import (
	"context"
	"errors"

	"github.com/gotenberg/gotenberg/v8/pkg/gotenberg"
	"go.uber.org/zap"
)

// ApiMock is a mock for the [Uno] interface.
type ApiMock struct {
	PdfMock            func(ctx context.Context, logger *zap.Logger, inputPath, outputPath string, options PdfOptions) error
	DocumentFormatMock func(ctx context.Context, logger *zap.Logger, inputPath, outputPath string, formatExt string) error
	ExtensionsMock     func() []string
}

func (api *ApiMock) Pdf(ctx context.Context, logger *zap.Logger, inputPath, outputPath string, options PdfOptions) error {
	return api.PdfMock(ctx, logger, inputPath, outputPath, options)
}

func (api *ApiMock) DocumentFormat(ctx context.Context, logger *zap.Logger, inputPath, outputPath string, formatExt string) error {
	return api.DocumentFormatMock(ctx, logger, inputPath, outputPath, formatExt)
}

func (api *ApiMock) Extensions() []string {
	return api.ExtensionsMock()
}

// ProviderMock is a mock for the [Provider] interface.
type ProviderMock struct {
	LibreOfficeMock func() (Uno, error)
}

func (provider *ProviderMock) LibreOffice() (Uno, error) {
	return provider.LibreOfficeMock()
}

// libreOfficeMock is a mock for the [libreOffice] interface.
type libreOfficeMock struct {
	errCoreDumpedCount int

	gotenberg.ProcessMock
	pdfMock            func(ctx context.Context, logger *zap.Logger, inputPath, outputPath string, options PdfOptions) error
	documentFormatMock func(ctx context.Context, logger *zap.Logger, inputPath, outputPath string, formatExt string) error
}

func (b *libreOfficeMock) pdf(ctx context.Context, logger *zap.Logger, inputPath, outputPath string, options PdfOptions) error {
	err := b.pdfMock(ctx, logger, inputPath, outputPath, options)
	if errors.Is(err, ErrCoreDumped) {
		b.errCoreDumpedCount += 1
	}
	if b.errCoreDumpedCount > 1 {
		return nil
	}
	return err
}

func (b *libreOfficeMock) documentFormat(ctx context.Context, logger *zap.Logger, inputPath, outputPath string, formatExt string) error {
	err := b.documentFormatMock(ctx, logger, inputPath, outputPath, formatExt)
	if errors.Is(err, ErrCoreDumped) {
		b.errCoreDumpedCount += 1
	}
	if b.errCoreDumpedCount > 1 {
		return nil
	}
	return err
}

// Interface guards.
var (
	_ Uno         = (*ApiMock)(nil)
	_ Provider    = (*ProviderMock)(nil)
	_ libreOffice = (*libreOfficeMock)(nil)
)

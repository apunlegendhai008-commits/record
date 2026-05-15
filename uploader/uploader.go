package uploader

import (
	"fmt"
	"log"
	"sync"
)

// UploadResult contains the result of an upload to a specific host
type UploadResult struct {
	Host         string
	DownloadLink string
	Error        error
}

// MultiHostUploader handles uploading to multiple hosts simultaneously
type MultiHostUploader struct {
	gofile       *GoFileUploader
	turboviplay  *TurboViPlayUploader
	voesx        *VoeSXUploader
	streamtape   *StreamtapeUploader
}

// NewMultiHostUploader creates a new multi-host uploader
func NewMultiHostUploader(turboViPlayAPIKey, voeSXAPIKey, streamtapeLogin, streamtapeAPIKey string) *MultiHostUploader {
	return &MultiHostUploader{
		gofile:       NewGoFileUploader(),
		turboviplay:  NewTurboViPlayUploader(turboViPlayAPIKey),
		voesx:        NewVoeSXUploader(voeSXAPIKey),
		streamtape:   NewStreamtapeUploader(streamtapeLogin, streamtapeAPIKey),
	}
}

// UploadToAll uploads a file to all configured hosts in parallel
// Returns a slice of results, one for each host
func (m *MultiHostUploader) UploadToAll(filePath string) []UploadResult {
	var wg sync.WaitGroup
	results := []UploadResult{}
	resultsMu := sync.Mutex{}
	
	// Upload to GoFile
	wg.Add(1)
	go func() {
		defer wg.Done()
		log.Printf("Starting upload to GoFile for %s", filePath)
		link, err := m.gofile.Upload(filePath)
		resultsMu.Lock()
		results = append(results, UploadResult{
			Host:         "GoFile",
			DownloadLink: link,
			Error:        err,
		})
		resultsMu.Unlock()
		if err != nil {
			log.Printf("GoFile upload failed: %v", err)
		} else {
			log.Printf("GoFile upload successful: %s", link)
		}
	}()
	
	// Upload to TurboViPlay (only if API key is configured)
	if m.turboviplay != nil && m.turboviplay.apiKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			log.Printf("Starting upload to TurboViPlay for %s", filePath)
			link, err := m.turboviplay.Upload(filePath)
			resultsMu.Lock()
			results = append(results, UploadResult{
				Host:         "TurboViPlay",
				DownloadLink: link,
				Error:        err,
			})
			resultsMu.Unlock()
			if err != nil {
				log.Printf("TurboViPlay upload failed: %v", err)
			} else {
				log.Printf("TurboViPlay upload successful: %s", link)
			}
		}()
	}
	
	// Upload to VOE.sx (only if API key is configured)
	if m.voesx != nil && m.voesx.apiKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			log.Printf("Starting upload to VOE.sx for %s", filePath)
			link, err := m.voesx.Upload(filePath)
			resultsMu.Lock()
			results = append(results, UploadResult{
				Host:         "VOE.sx",
				DownloadLink: link,
				Error:        err,
			})
			resultsMu.Unlock()
			if err != nil {
				log.Printf("VOE.sx upload failed: %v", err)
			} else {
				log.Printf("VOE.sx upload successful: %s", link)
			}
		}()
	}
	
	// Upload to Streamtape (only if credentials are configured)
	if m.streamtape != nil && m.streamtape.login != "" && m.streamtape.apiKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			log.Printf("Starting upload to Streamtape for %s", filePath)
			link, err := m.streamtape.Upload(filePath)
			resultsMu.Lock()
			results = append(results, UploadResult{
				Host:         "Streamtape",
				DownloadLink: link,
				Error:        err,
			})
			resultsMu.Unlock()
			if err != nil {
				log.Printf("Streamtape upload failed: %v", err)
			} else {
				log.Printf("Streamtape upload successful: %s", link)
			}
		}()
	}
	
	// Wait for all uploads to complete
	wg.Wait()
	
	return results
}

// GetSuccessfulUploads returns only the successful upload results
func GetSuccessfulUploads(results []UploadResult) []UploadResult {
	var successful []UploadResult
	for _, result := range results {
		if result.Error == nil && result.DownloadLink != "" {
			successful = append(successful, result)
		}
	}
	return successful
}

// FormatResults formats upload results into a readable string
func FormatResults(results []UploadResult) string {
	var output string
	successCount := 0
	
	for _, result := range results {
		if result.Error == nil && result.DownloadLink != "" {
			output += fmt.Sprintf("✓ %s: %s\n", result.Host, result.DownloadLink)
			successCount++
		} else {
			output += fmt.Sprintf("✗ %s: %v\n", result.Host, result.Error)
		}
	}
	
	output = fmt.Sprintf("Upload completed: %d/%d successful\n%s", successCount, len(results), output)
	return output
}

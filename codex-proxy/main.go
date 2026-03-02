package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// Config holds the proxy configuration
type Config struct {
	ListenAddr   string
	UpstreamURL  string
	UpstreamAPIKey string
}

// Responses API types (Codex format)
type ResponsesInputItem struct {
	Type    string `json:"type"`    // "message"
	Role    string `json:"role"`    // "user", "assistant", "system", "developer"
	Content string `json:"content"` // For simple text content
}

type ResponsesToolCall struct {
	ID   string `json:"id"`
	Type string `json:"type"`
	Function struct {
		Name      string `json:"name"`
		Arguments string `json:"arguments"`
	} `json:"function"`
}

type ResponsesToolCallOutput struct {
	Type    string `json:"type"`    // "function_call_output"
	CallID  string `json:"call_id"`
	Output  string `json:"output"`
}

type ResponsesContentPart struct {
	Type string `json:"type"`
	Text string `json:"text,omitempty"`
}

type ResponsesInputItemComplex struct {
	Type    string              `json:"type"`
	Role    string              `json:"role"`
	Content interface{}         `json:"content"` // Can be string or []ResponsesContentPart
}

type ResponsesRequest struct {
	Model        string      `json:"model"`
	Input        interface{} `json:"input"` // Can be []ResponsesInputItem or string
	Instructions string      `json:"instructions,omitempty"`
	Tools        []interface{} `json:"tools,omitempty"`
	Stream       bool        `json:"stream,omitempty"`
	MaxTokens    int         `json:"max_output_tokens,omitempty"`
	Temperature  *float64    `json:"temperature,omitempty"`
	TopP         *float64    `json:"top_p,omitempty"`
}

// Chat Completion API types (OpenAI/llama.cpp format)
type ChatMessage struct {
	Role             string `json:"role"`
	Content          string `json:"content"`
	ReasoningContent string `json:"reasoning_content,omitempty"` // llama.cpp extension
}

// GetContent returns content, falling back to reasoning_content if content is empty
func (m *ChatMessage) GetContent() string {
	if m.Content != "" {
		return m.Content
	}
	return m.ReasoningContent
}

type ChatCompletionRequest struct {
	Model       string        `json:"model"`
	Messages    []ChatMessage `json:"messages"`
	Stream      bool          `json:"stream,omitempty"`
	MaxTokens   int           `json:"max_tokens,omitempty"`
	Temperature *float64      `json:"temperature,omitempty"`
	TopP        *float64      `json:"top_p,omitempty"`
}

// Response types
type ChatCompletionResponse struct {
	ID      string `json:"id"`
	Object  string `json:"object"`
	Created int64  `json:"created"`
	Model   string `json:"model"`
	Choices []struct {
		Index        int          `json:"index"`
		Message      *ChatMessage `json:"message,omitempty"`
		Delta        *ChatMessage `json:"delta,omitempty"`
		FinishReason string       `json:"finish_reason"`
	} `json:"choices"`
	Usage struct {
		PromptTokens     int `json:"prompt_tokens"`
		CompletionTokens int `json:"completion_tokens"`
		TotalTokens      int `json:"total_tokens"`
	} `json:"usage"`
}

// Responses API response types
type ResponsesResponse struct {
	ID        string `json:"id"`
	Object    string `json:"object"`
	CreatedAt int64  `json:"created_at"`
	Model     string `json:"model"`
	Output    []struct {
		Type    string `json:"type"`
		Role    string `json:"role,omitempty"`
		Content string `json:"content,omitempty"`
		Status  string `json:"status,omitempty"`
	} `json:"output"`
	Usage struct {
		InputTokens  int `json:"input_tokens"`
		OutputTokens int `json:"output_tokens"`
		TotalTokens  int `json:"total_tokens"`
	} `json:"usage"`
	Status string `json:"status"`
}

// SSE event types for Responses API
type ResponsesSSEEvent struct {
	Type    string `json:"type"`
	Index   int    `json:"index,omitempty"`
	Content string `json:"content,omitempty"`
	Delta   string `json:"delta,omitempty"`
	Status  string `json:"status,omitempty"`
}

var config Config

// HTTP client with timeout
var httpClient *http.Client

func main() {
	// Create HTTP client with timeout
	httpClient = &http.Client{
		Timeout: 5 * time.Minute, // 5 minute timeout for long generations
	}
	// Load configuration from environment
	config = Config{
		ListenAddr:     getEnv("LISTEN_ADDR", ":8080"),
		UpstreamURL:    getEnv("UPSTREAM_URL", "http://localhost:8081/v1"),
		UpstreamAPIKey: getEnv("UPSTREAM_API_KEY", ""),
	}

	log.Printf("Starting codex-proxy on %s", config.ListenAddr)
	log.Printf("Upstream URL: %s", config.UpstreamURL)

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery())
	// Add request logging
	r.Use(func(c *gin.Context) {
		log.Printf("[REQUEST] %s %s", c.Request.Method, c.Request.URL.Path)
		c.Next()
	})

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// Models endpoint (passthrough)
	r.GET("/v1/models", proxyModels)

	// Responses API endpoint (Codex format) -> Chat Completions
	r.POST("/v1/responses", handleResponses)

	// Also support direct chat completions passthrough
	r.POST("/v1/chat/completions", proxyChatCompletions)

	log.Fatal(r.Run(config.ListenAddr))
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// proxyModels forwards the models request to upstream
func proxyModels(c *gin.Context) {
	req, err := http.NewRequest("GET", config.UpstreamURL+"/models", nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if config.UpstreamAPIKey != "" {
		req.Header.Set("Authorization", "Bearer "+config.UpstreamAPIKey)
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	defer resp.Body.Close()

	c.DataFromReader(resp.StatusCode, resp.ContentLength, resp.Header.Get("Content-Type"), resp.Body, nil)
}

// handleResponses converts Responses API to Chat Completions and back
func handleResponses(c *gin.Context) {
	var req ResponsesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request: " + err.Error()})
		return
	}

	log.Printf("[HANDLER] Received request - Model: %s, Stream: %v", req.Model, req.Stream)

	// Convert Responses API to Chat Completions
	chatReq := convertToChatCompletion(req)

	// Marshal the chat completion request
	body, err := json.Marshal(chatReq)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to marshal request"})
		return
	}

	// Create request to upstream
	upstreamURL := config.UpstreamURL + "/chat/completions"
	log.Printf("[HANDLER] Calling upstream: %s", upstreamURL)
	log.Printf("[HANDLER] Request body: %s", string(body))

	httpReq, err := http.NewRequest("POST", upstreamURL, bytes.NewReader(body))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	httpReq.Header.Set("Content-Type", "application/json")
	if config.UpstreamAPIKey != "" {
		httpReq.Header.Set("Authorization", "Bearer "+config.UpstreamAPIKey)
	}

	log.Printf("[HANDLER] Sending request to upstream...")
	resp, err := httpClient.Do(httpReq)
	log.Printf("[HANDLER] Upstream call returned")
	if err != nil {
		log.Printf("[HANDLER] Upstream error: %v", err)
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	defer resp.Body.Close()

	log.Printf("[HANDLER] Upstream response status: %d", resp.StatusCode)

	if req.Stream {
		handleStreamingResponse(c, resp, req.Model)
	} else {
		handleNonStreamingResponse(c, resp, req.Model)
	}
	log.Printf("[HANDLER] Response sent")
}

// convertToChatCompletion converts Responses API request to Chat Completions format
func convertToChatCompletion(req ResponsesRequest) ChatCompletionRequest {
	chatReq := ChatCompletionRequest{
		Model:    req.Model,
		Messages: []ChatMessage{},
		Stream:   req.Stream,
	}

	// Add instructions as system message if present
	if req.Instructions != "" {
		chatReq.Messages = append(chatReq.Messages, ChatMessage{
			Role:    "system",
			Content: req.Instructions,
		})
	}

	// Process input
	switch input := req.Input.(type) {
	case string:
		// Simple string input
		chatReq.Messages = append(chatReq.Messages, ChatMessage{
			Role:    "user",
			Content: input,
		})
	case []interface{}:
		// Array of input items
		for _, item := range input {
			if m, ok := item.(map[string]interface{}); ok {
				role := getString(m, "role")
				content := getString(m, "content")
				itemType := getString(m, "type")

				// Handle content that might be an array
				if contentArr, ok := m["content"].([]interface{}); ok {
					content = extractTextFromParts(contentArr)
				}

				// Map roles
				switch role {
				case "developer":
					role = "system"
				}

				// Only add message items
				if itemType == "message" || itemType == "" {
					chatReq.Messages = append(chatReq.Messages, ChatMessage{
						Role:    role,
						Content: content,
					})
				}
			}
		}
	}

	// Copy optional parameters
	if req.MaxTokens > 0 {
		chatReq.MaxTokens = req.MaxTokens
	} else {
		// Default max_tokens for local models to avoid long waits
		chatReq.MaxTokens = 500
	}
	if req.Temperature != nil {
		chatReq.Temperature = req.Temperature
	}
	if req.TopP != nil {
		chatReq.TopP = req.TopP
	}

	return chatReq
}

func getString(m map[string]interface{}, key string) string {
	if v, ok := m[key].(string); ok {
		return v
	}
	return ""
}

func extractTextFromParts(parts []interface{}) string {
	var text string
	for _, part := range parts {
		if p, ok := part.(map[string]interface{}); ok {
			if p["type"] == "input_text" || p["type"] == "output_text" || p["type"] == "text" {
				if t, ok := p["text"].(string); ok {
					text += t
				}
			}
		}
	}
	return text
}

// handleNonStreamingResponse handles non-streaming response conversion
func handleNonStreamingResponse(c *gin.Context, resp *http.Response, model string) {
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to read response"})
		return
	}

	var chatResp ChatCompletionResponse
	if err := json.Unmarshal(body, &chatResp); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to parse response"})
		return
	}

	// Convert to Responses API format
	responsesResp := convertToResponsesResponse(chatResp, model)

	c.JSON(http.StatusOK, responsesResp)
}

// convertToResponsesResponse converts Chat Completion response to Responses API format
func convertToResponsesResponse(chatResp ChatCompletionResponse, model string) ResponsesResponse {
	resp := ResponsesResponse{
		ID:        chatResp.ID,
		Object:    "response",
		CreatedAt: chatResp.Created,
		Model:     model,
		Status:    "completed",
		Usage: struct {
			InputTokens  int `json:"input_tokens"`
			OutputTokens int `json:"output_tokens"`
			TotalTokens  int `json:"total_tokens"`
		}{
			InputTokens:  chatResp.Usage.PromptTokens,
			OutputTokens: chatResp.Usage.CompletionTokens,
			TotalTokens:  chatResp.Usage.TotalTokens,
		},
	}

	// Add output message
	if len(chatResp.Choices) > 0 {
		choice := chatResp.Choices[0]
		if choice.Message != nil {
			resp.Output = []struct {
				Type    string `json:"type"`
				Role    string `json:"role,omitempty"`
				Content string `json:"content,omitempty"`
				Status  string `json:"status,omitempty"`
			}{
				{
					Type:    "message",
					Role:    choice.Message.Role,
					Content: choice.Message.GetContent(),
				},
			}
		}
	}

	return resp
}

// splitSSEEvent splits the reader on SSE event boundaries (\n\n) so each token is one full event.
func splitSSEEvent(data []byte, atEOF bool) (advance int, token []byte, err error) {
	if atEOF && len(data) == 0 {
		return 0, nil, nil
	}
	if i := bytes.Index(data, []byte("\n\n")); i >= 0 {
		return i + 2, data[:i], nil
	}
	if atEOF {
		return len(data), data, nil
	}
	return 0, nil, nil
}

// handleStreamingResponse handles streaming response conversion
func handleStreamingResponse(c *gin.Context, resp *http.Response, model string) {
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("Transfer-Encoding", "chunked")

	flusher, ok := c.Writer.(http.Flusher)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "streaming not supported"})
		return
	}
	// Commit status and headers immediately so the client gets a stream and can render incrementally
	c.Writer.WriteHeader(http.StatusOK)
	flusher.Flush()

	responseID := fmt.Sprintf("resp_%d", time.Now().UnixNano())
	messageID := fmt.Sprintf("msg_%d", time.Now().UnixNano())
	createdAt := time.Now().Unix()
	seqNum := 0

	// Helper to send event
	sendEvent := func(eventType string, data map[string]interface{}) {
		data["type"] = eventType
		dataBytes, _ := json.Marshal(data)
		c.Writer.Write([]byte(fmt.Sprintf("data: %s\n\n", string(dataBytes))))
		flusher.Flush()
	}

	// 1. Send response.created
	sendEvent("response.created", map[string]interface{}{
		"sequence_number": seqNum,
		"response": map[string]interface{}{
			"id":         responseID,
			"object":     "response",
			"created_at": createdAt,
			"model":      model,
			"status":     "in_progress",
		},
	})
	seqNum++

	// 2. Send response.in_progress
	sendEvent("response.in_progress", map[string]interface{}{
		"sequence_number": seqNum,
		"response": map[string]interface{}{
			"id":         responseID,
			"object":     "response",
			"created_at": createdAt,
			"model":      model,
			"status":     "in_progress",
		},
	})
	seqNum++

	// 3. Send response.output_item.added
	sendEvent("response.output_item.added", map[string]interface{}{
		"sequence_number": seqNum,
		"output_index":    0,
		"item": map[string]interface{}{
			"id":      messageID,
			"type":    "message",
			"role":    "assistant",
			"status":  "in_progress",
			"content": []interface{}{},
		},
	})
	seqNum++

	// 4. Send response.content_part.added
	sendEvent("response.content_part.added", map[string]interface{}{
		"sequence_number": seqNum,
		"output_index":    0,
		"content_index":   0,
		"item_id":         messageID,
		"part": map[string]interface{}{
			"type": "output_text",
			"text": "",
		},
	})
	seqNum++

	// Read upstream by SSE event boundary (\n\n) so we get each event even when
	// JSON is split across TCP chunks or pretty-printed with newlines
	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	scanner.Split(splitSSEEvent)
	var contentBuffer strings.Builder

	for scanner.Scan() {
		block := strings.TrimSpace(scanner.Text())
		if block == "" {
			continue
		}
		if !strings.HasPrefix(block, "data: ") {
			continue
		}
		payload := strings.TrimSpace(strings.TrimPrefix(block, "data: "))
		if payload == "[DONE]" {
			break
		}

		var chatResp ChatCompletionResponse
		if err := json.Unmarshal([]byte(payload), &chatResp); err != nil {
			continue
		}

		if len(chatResp.Choices) > 0 {
			choice := chatResp.Choices[0]
			if choice.Delta != nil {
				deltaContent := choice.Delta.GetContent()
				if deltaContent != "" {
					contentBuffer.WriteString(deltaContent)

					// Send response.output_text.delta
					sendEvent("response.output_text.delta", map[string]interface{}{
						"sequence_number": seqNum,
						"output_index":    0,
						"content_index":   0,
						"item_id":         messageID,
						"delta":           deltaContent,
					})
					seqNum++
				}
			}
		}
	}

	// 5. Send response.output_text.done
	sendEvent("response.output_text.done", map[string]interface{}{
		"sequence_number": seqNum,
		"output_index":    0,
		"content_index":   0,
		"item_id":         messageID,
		"text":            contentBuffer.String(),
	})
	seqNum++

	// 6. Send response.content_part.done
	sendEvent("response.content_part.done", map[string]interface{}{
		"sequence_number": seqNum,
		"output_index":    0,
		"content_index":   0,
		"item_id":         messageID,
		"part": map[string]interface{}{
			"type": "output_text",
			"text": contentBuffer.String(),
		},
	})
	seqNum++

	// 7. Send response.output_item.done
	sendEvent("response.output_item.done", map[string]interface{}{
		"sequence_number": seqNum,
		"output_index":    0,
		"item": map[string]interface{}{
			"id":      messageID,
			"type":    "message",
			"role":    "assistant",
			"status":  "completed",
			"content": []interface{}{
				map[string]interface{}{
					"type": "output_text",
					"text": contentBuffer.String(),
				},
			},
		},
	})
	seqNum++

	// 8. Send response.completed
	sendEvent("response.completed", map[string]interface{}{
		"sequence_number": seqNum,
		"response": map[string]interface{}{
			"id":         responseID,
			"object":     "response",
			"created_at": createdAt,
			"model":      model,
			"status":     "completed",
		},
	})

	c.Writer.Write([]byte("data: [DONE]\n\n"))
	flusher.Flush()
}

func writeSSE(c *gin.Context, eventType, eventName string, data interface{}) {
	dataBytes, _ := json.Marshal(data)
	// Only write event line if explicitly requested
	// Many SSE clients parse based on the "type" field in JSON data
	if eventType == "event" && eventName != "" {
		c.Writer.Write([]byte(fmt.Sprintf("event: %s\n", eventName)))
	}
	c.Writer.Write([]byte(fmt.Sprintf("data: %s\n\n", string(dataBytes))))
}

// proxyChatCompletions forwards chat completions directly
func proxyChatCompletions(c *gin.Context) {
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	req, err := http.NewRequest("POST", config.UpstreamURL+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	req.Header.Set("Content-Type", "application/json")
	if config.UpstreamAPIKey != "" {
		req.Header.Set("Authorization", "Bearer "+config.UpstreamAPIKey)
	}

	// Copy authorization header from original request if present
	if auth := c.GetHeader("Authorization"); auth != "" && config.UpstreamAPIKey == "" {
		req.Header.Set("Authorization", auth)
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	defer resp.Body.Close()

	// Copy headers
	for k, v := range resp.Header {
		c.Header(k, v[0])
	}

	c.DataFromReader(resp.StatusCode, resp.ContentLength, resp.Header.Get("Content-Type"), resp.Body, nil)
}

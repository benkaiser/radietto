---
# radietto-uoku
title: Implement OpenRouter LLM service
status: completed
type: feature
priority: high
created_at: 2026-04-28T13:52:44Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-ws9t
blocking:
    - radietto-72gk
---

Build the service that calls OpenRouter API for LLM-powered song generation.

## Requirements:
- Use openai/gpt-oss-120b model
- Prefer Cerebras provider for fast throughput (use OpenRouter provider routing)
- Parse JSON responses with song title + artist pairs
- Handle rate limits and errors gracefully

## Prompt Design:
The prompt should:
1. Describe the station mood/vibe
2. Include user genre taste sliders (only mention non-neutral ones, or all if all neutral)
3. Include recent feedback history (last N rated songs with their ratings)
4. Request exactly 5 songs as JSON array [{title, artist}]
5. Emphasize balance - don't go all-in on one genre unless slider is very high (8+)
6. Avoid repeating songs already in queue or recently played/rated

## OpenRouter API format:
- POST to https://openrouter.ai/api/v1/chat/completions
- Headers: Authorization: Bearer $OPENROUTER_API_KEY
- Provider preferences: {"order": ["Cerebras"], "allow_fallbacks": true}
- response_format: {"type": "json_object"} for structured output

## Checklist
- [x] Create lib/services/llm_service.dart
- [x] Implement song generation prompt builder
- [x] Implement station name/tagline/emoji generation prompt
- [x] Parse JSON responses into Song models
- [x] Add error handling and retry logic
- [x] Rate limit API calls
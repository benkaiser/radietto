---
# radietto-ws9t
title: LLM Integration (OpenRouter)
status: completed
type: epic
priority: normal
created_at: 2026-04-28T13:51:42Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-g23a
---

Integrate OpenRouter API for LLM-powered song selection using openai/gpt-oss-120b model.

## Checklist
- [x] OpenRouter API service with HTTP client
- [x] Use openai/gpt-oss-120b model with Cerebras provider preference for fast throughput
- [x] Prompt engineering for song generation (taste-aware, feedback-aware)
- [x] JSON response parsing for song lists
- [x] Station name/tagline generation
- [x] Error handling and retry logic
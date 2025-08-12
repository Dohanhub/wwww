# DoganHub Multi-Domain Environment Configuration

This document explains the environment variables in the `.env` file and how to leverage the "super powers" they enable across your DoganHub multi-domain architecture.

## Core AI Configuration

```properties
OPENAI_API_KEY=sk-proj-XXXXXXXXXXXX
OPENAI_MODEL=gpt-4o-mini
WHISPER_MODEL=whisper-1
```

These keys power the core AI capabilities across all domains. The system is designed to use OpenAI's models by default but can fall back to alternative providers.

## Zencoder Integration

```properties
ZENCODER_CLIENT_ID=2d7cfeb6-9862-40c9-bd1b-43287d7ff030
ZENCODER_SECRET_KEY=94e341db-82c9-4083-acfa-b770f5347103
ZENCODER_API_URL=https://api.zencoder.ai
```

The Zencoder keys allow seamless media processing across all domains. When enabled with `AI_ZENCODER_INTEGRATION=true`, the system will:

1. Automatically detect media uploads
2. Process them through Zencoder
3. Monitor encoding status via webhooks
4. Alert via Slack when issues occur
5. Update the AI agent with processing status

## Local LLM Configuration

```properties
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.1:8b
OLLAMA_FALLBACK_MODEL=phi3:mini
```

For cost optimization and privacy, the system can leverage local language models through Ollama. The `AI_PROVIDER_PRIORITY` setting determines the order in which providers are tried.

## Super Power: AI Agent Configuration

```properties
AI_PROVIDER_PRIORITY=ollama,openai,zencoder
AI_LEARNING_MODE=true
AI_24_7_MODE=true
AI_MEMORY_PERSISTENCE=true
AI_DOMAIN_AWARENESS=true
AI_ZENCODER_INTEGRATION=true
AI_CROSS_DOMAIN_MEMORY=true
AI_BACKGROUND_LEARNING=true
AI_AUTOTUNE_PARAMETERS=true
```

These settings unlock the advanced capabilities of your multi-domain AI system:

- **AI_DOMAIN_AWARENESS**: The agent automatically detects which domain it's operating in and adjusts its responses accordingly
- **AI_CROSS_DOMAIN_MEMORY**: User interactions are remembered across all domains
- **AI_BACKGROUND_LEARNING**: The system continuously improves by analyzing user interactions in the background
- **AI_AUTOTUNE_PARAMETERS**: The system automatically adjusts its parameters for optimal performance

## Super Power: Multi-Domain Configuration

```properties
DOMAIN_DOGANHUB=https://doganhub.com
DOMAIN_DOGANCONSULT=https://doganconsult.com
DOMAIN_AHMETDOGAN=https://ahmetdogan.info
DOMAIN_SHARED_RESOURCES=/shared
DOMAIN_DEFAULT=doganhub
```

This configuration enables seamless operation across all three domains:

1. Shared resources are automatically located
2. Domain-specific content is properly served
3. Cross-domain navigation is optimized
4. The AI agent provides domain-appropriate responses

## Super Power: Advanced Security

```properties
JWT_SECRET=eF5cH8jK2mN6pQ9rT3vX7zL1bD4gA0sW
JWT_EXPIRY=86400
RATE_LIMIT_REQUESTS=100
RATE_LIMIT_WINDOW=60
SECURE_COOKIES=true
CSRF_PROTECTION=true
ALLOWED_ORIGINS=https://doganhub.com,https://doganconsult.com,https://ahmetdogan.info
```

These settings implement enterprise-grade security across your platform:

- **JWT Authentication**: Secure token-based authentication
- **Rate Limiting**: Protection against abuse
- **CSRF Protection**: Prevents cross-site request forgery attacks
- **Origin Restrictions**: Only allowed domains can access the API

## Super Power: DV Path Integration

```properties
DV_PATH=c:\\Users\\dogan\\OneDrive - DoganHub\\DV
```

This setting enables the system to access resources from your DV path, allowing:

1. Custom model loading from local storage
2. Access to proprietary datasets
3. Integration with specialized tools in the DV directory

## How to Use These Super Powers

### Domain Awareness

The system automatically detects the current domain and adjusts its behavior. To leverage this:

```javascript
// In your domain-specific JavaScript:
fetch('/api/agent/query', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ 
    query: "What services do you offer?",
    context: { currentPage: window.location.pathname }
  })
})
.then(response => response.json())
.then(data => {
  // The response will be domain-appropriate
  console.log(data.response);
});
```

### Zencoder Integration

When uploading media files:

```javascript
// Automatically integrates with Zencoder
const formData = new FormData();
formData.append('media', fileInput.files[0]);

fetch('/api/upload/media', {
  method: 'POST',
  body: formData
})
.then(response => response.json())
.then(data => {
  // The system will handle encoding through Zencoder
  // and notify you of status changes
  console.log(data.jobId);
});
```

### Cross-Domain Memory

Users' preferences and interactions are remembered across domains:

```javascript
// On any domain, the system remembers user preferences
fetch('/api/user/preferences', {
  method: 'GET',
  headers: { 'Authorization': `Bearer ${userToken}` }
})
.then(response => response.json())
.then(data => {
  // User preferences from any domain are available
  console.log(data.preferences);
});
```

## Monitoring and Management

You can monitor the system's operation through:

1. Slack notifications (configured via `SLACK_WEBHOOK_URL`)
2. The admin dashboard at `/admin` (requires admin credentials)
3. Log files in the `logs/` directory

## Troubleshooting

If you encounter issues:

1. Check the logs in the `logs/` directory
2. Verify all environment variables are correctly set
3. Ensure the DV path is accessible
4. Confirm that Zencoder API credentials are valid

For assistance, contact the development team at dev@doganhub.com

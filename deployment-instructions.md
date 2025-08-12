# Multi-Domain Website Deployment Instructions

## Overview
This document provides comprehensive instructions for deploying and maintaining the three interconnected domains:
- **DoganHub.com** - Main hub with light color theme
- **DoganConsult.com** - Innovation and next-decade solutions
- **AhmetDogan.info** - Personal profile and expertise

## Folder Structure
```
domains/
├── shared/           # Shared resources across all domains
│   ├── css/          # Common stylesheets
│   ├── js/           # Common JavaScript
│   └── images/       # Shared images
├── doganhub/         # DoganHub.com website files
├── doganconsult/     # DoganConsult.com website files
└── ahmetdogan/       # AhmetDogan.info website files
```

## Deployment Steps

### 1. Server Requirements
- Web server with PHP 7.4+ support
- SSL certificate for each domain
- 2GB+ RAM for optimal performance

### 2. Domain Configuration
- Point each domain to its respective folder:
  - `doganhub.com` → `/domains/doganhub/`
  - `doganconsult.com` → `/domains/doganconsult/`
  - `ahmetdogan.info` → `/domains/ahmetdogan/`

### 3. Upload Files
- Upload all content from the `domains` folder to your server's web root or designated directory
- Ensure proper permissions (typically 755 for folders, 644 for files)

### 4. Configure Shared Resources
- The `shared` folder should be accessible from all domains
- Verify that relative paths in each domain correctly reference shared resources

### 5. SSL Configuration
- Install SSL certificates for each domain
- Configure web server to force HTTPS

### 6. Testing
- Test cross-domain navigation on desktop and mobile devices
- Verify AI agent functionality across domains
- Check language switching functionality
- Test contact forms on each domain

## Maintenance

### Regular Updates
- Use the included `update-domains.sh` script for synchronized updates
- Schedule monthly checks for plugin and dependency updates

### Backup Strategy
- Daily automated backups of all three domains
- Store backups in separate geographical location
- Test restoration process quarterly

## Zencoder Integration

To prevent issues with Zencoder:
1. Always use the provided `zencoder-integration.js` script
2. Avoid multiple instances of video players on the same page
3. Monitor browser console for coordination errors

## AI Agent Management

The AI assistant is configured to work across all domains and coordinate activities:

1. Agent settings can be modified in `shared/js/floating-agent.js`
2. Customize responses in the `getHelpResponse()`, `getContactResponse()`, etc. functions
3. The agent automatically adapts to the current domain

## Need Help?

Contact technical support at support@doganhub.com

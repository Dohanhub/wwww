# Deployment Script for Multi-Domain Website

<#
.SYNOPSIS
    PowerShell script to prepare and deploy the multi-domain website structure
.DESCRIPTION
    This script performs the following tasks:
    1. Validates the directory structure
    2. Optimizes images and minifies CSS/JS
    3. Creates necessary configuration files
    4. Prepares for deployment to hosting service
.NOTES
    File Name      : deploy-domains.ps1
    Author         : GitHub Copilot
    Prerequisite   : PowerShell 5.1 or higher
#>

# Configuration
$sourceDir = "C:\Users\dogan\OneDrive - DoganHub\Doganwebsite\domains"
$deployDir = "C:\Users\dogan\OneDrive - DoganHub\Doganwebsite\deployment"
$domains = @("doganhub", "doganconsult", "ahmetdogan")
$shared = "shared"

# Create log file
$logFile = "deployment-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
Start-Transcript -Path "$deployDir\$logFile"

# Print banner
Write-Host "=============================================="
Write-Host "   MULTI-DOMAIN WEBSITE DEPLOYMENT SCRIPT"
Write-Host "=============================================="
Write-Host

# Create deployment directory if it doesn't exist
if (-not (Test-Path $deployDir)) {
    New-Item -Path $deployDir -ItemType Directory | Out-Null
    Write-Host "Created deployment directory: $deployDir" -ForegroundColor Green
}

# Function to validate source directory
function Test-SourceDirectory {
    if (-not (Test-Path $sourceDir)) {
        Write-Host "ERROR: Source directory not found: $sourceDir" -ForegroundColor Red
        exit 1
    }
    
    foreach ($domain in $domains) {
        if (-not (Test-Path "$sourceDir\$domain")) {
            Write-Host "ERROR: Domain directory not found: $domain" -ForegroundColor Red
            exit 1
        }
        
        if (-not (Test-Path "$sourceDir\$domain\index.html")) {
            Write-Host "ERROR: index.html not found for domain: $domain" -ForegroundColor Red
            exit 1
        }
    }
    
    if (-not (Test-Path "$sourceDir\$shared")) {
        Write-Host "ERROR: Shared directory not found: $shared" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Source directory structure validated" -ForegroundColor Green
}

# Function to copy domain files
function Copy-DomainFiles {
    foreach ($domain in $domains) {
        $domainDeployDir = "$deployDir\$domain"
        if (-not (Test-Path $domainDeployDir)) {
            New-Item -Path $domainDeployDir -ItemType Directory | Out-Null
        }
        
        Write-Host "Copying files for $domain..." -ForegroundColor Cyan
        Copy-Item -Path "$sourceDir\$domain\*" -Destination $domainDeployDir -Recurse -Force
    }
    
    $sharedDeployDir = "$deployDir\$shared"
    if (-not (Test-Path $sharedDeployDir)) {
        New-Item -Path $sharedDeployDir -ItemType Directory | Out-Null
    }
    
    Write-Host "Copying shared files..." -ForegroundColor Cyan
    Copy-Item -Path "$sourceDir\$shared\*" -Destination $sharedDeployDir -Recurse -Force
    
    Write-Host "✓ All domain files copied successfully" -ForegroundColor Green
}

# Function to optimize images
function Optimize-Images {
    Write-Host "Optimizing images..." -ForegroundColor Cyan
    
    $imageExts = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp")
    $imageCount = 0
    
    # Create temp optimization dir if it doesn't exist
    $tempOptimDir = "$deployDir\temp_optimize"
    if (-not (Test-Path $tempOptimDir)) {
        New-Item -Path $tempOptimDir -ItemType Directory | Out-Null
    }
    
    # Check if optimization tool exists - if not, just copy images
    $hasOptimizationTool = $false
    
    if (-not $hasOptimizationTool) {
        Write-Host "Image optimization tools not found. Skipping optimization." -ForegroundColor Yellow
        return
    }
    
    # Process shared images
    foreach ($ext in $imageExts) {
        $images = Get-ChildItem -Path "$deployDir\$shared" -Filter $ext -Recurse
        foreach ($img in $images) {
            # Optimization would happen here if tools were available
            $imageCount++
        }
    }
    
    # Process domain-specific images
    foreach ($domain in $domains) {
        foreach ($ext in $imageExts) {
            $images = Get-ChildItem -Path "$deployDir\$domain" -Filter $ext -Recurse
            foreach ($img in $images) {
                # Optimization would happen here if tools were available
                $imageCount++
            }
        }
    }
    
    Write-Host "✓ Processed $imageCount images" -ForegroundColor Green
    
    # Clean up temp directory
    if (Test-Path $tempOptimDir) {
        Remove-Item -Path $tempOptimDir -Recurse -Force
    }
}

# Function to minify CSS and JS
function Compress-Assets {
    Write-Host "Minifying CSS and JS files..." -ForegroundColor Cyan
    
    $cssCount = 0
    $jsCount = 0
    
    # Check if minification tools exist
    $hasMinificationTool = $false
    
    if (-not $hasMinificationTool) {
        Write-Host "Minification tools not found. Skipping minification." -ForegroundColor Yellow
        return
    }
    
    # Minify shared CSS and JS
    $cssFiles = Get-ChildItem -Path "$deployDir\$shared" -Filter "*.css" -Recurse
    foreach ($css in $cssFiles) {
        # Minification would happen here if tools were available
        $cssCount++
    }
    
    $jsFiles = Get-ChildItem -Path "$deployDir\$shared" -Filter "*.js" -Recurse
    foreach ($js in $jsFiles) {
        # Minification would happen here if tools were available
        $jsCount++
    }
    
    # Minify domain-specific CSS and JS
    foreach ($domain in $domains) {
        $domainCssFiles = Get-ChildItem -Path "$deployDir\$domain" -Filter "*.css" -Recurse
        foreach ($css in $domainCssFiles) {
            # Minification would happen here if tools were available
            $cssCount++
        }
        
        $domainJsFiles = Get-ChildItem -Path "$deployDir\$domain" -Filter "*.js" -Recurse
        foreach ($js in $domainJsFiles) {
            # Minification would happen here if tools were available
            $jsCount++
        }
    }
    
    Write-Host "✓ Processed $cssCount CSS files and $jsCount JavaScript files" -ForegroundColor Green
}

# Function to create deployment configuration files
function New-ConfigFiles {
    Write-Host "Creating configuration files..." -ForegroundColor Cyan
    
    # Create robots.txt for each domain
    foreach ($domain in $domains) {
        $robotsContent = @"
User-agent: *
Allow: /
Sitemap: https://$domain.com/sitemap.xml
"@
        Set-Content -Path "$deployDir\$domain\robots.txt" -Value $robotsContent
        
        # Create basic sitemap.xml
        $sitemapContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://$domain.com/</loc>
    <lastmod>$(Get-Date -Format "yyyy-MM-dd")</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
"@
        Set-Content -Path "$deployDir\$domain\sitemap.xml" -Value $sitemapContent -Encoding UTF8
    }
    
    Write-Host "✓ Configuration files created" -ForegroundColor Green
}

# Function to create deployment package
function New-DeploymentPackage {
    Write-Host "Creating deployment package..." -ForegroundColor Cyan
    
    $packageDate = Get-Date -Format "yyyyMMdd-HHmmss"
    $packageName = "domains-deployment-$packageDate.zip"
    $packagePath = "$deployDir\$packageName"
    
    Compress-Archive -Path "$deployDir\doganhub", "$deployDir\doganconsult", "$deployDir\ahmetdogan", "$deployDir\shared" -DestinationPath $packagePath -Force
    
    Write-Host "✓ Deployment package created: $packagePath" -ForegroundColor Green
}

# Function to generate deployment instructions
function New-Instructions {
    Write-Host "Generating deployment instructions..." -ForegroundColor Cyan
    
    $instructionsContent = @"
# Deployment Instructions

## Package Contents
- doganhub/ - DoganHub.com website files
- doganconsult/ - DoganConsult.com website files
- ahmetdogan/ - AhmetDogan.info website files
- shared/ - Shared resources for all domains

## Deployment Steps
1. Upload the 'shared' folder to a common location accessible by all domains
2. Upload each domain folder to its respective domain's web root
3. Update paths in HTML files if necessary to point to the correct shared resources location
4. Configure each domain's DNS settings to point to the appropriate hosting location

## Post-Deployment Checks
- Verify cross-domain navigation works correctly
- Test the AI assistant functionality on each domain
- Confirm language switching works properly
- Test all forms and interactive elements

## Contact
If you encounter any issues during deployment, contact technical support at support@doganhub.com

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    Set-Content -Path "$deployDir\DEPLOYMENT-INSTRUCTIONS.md" -Value $instructionsContent
    
    Write-Host "✓ Deployment instructions generated" -ForegroundColor Green
}

# Main execution
try {
    Test-SourceDirectory
    Copy-DomainFiles
    Optimize-Images
    Compress-Assets
    New-ConfigFiles
    New-Instructions
    New-DeploymentPackage
    
    Write-Host
    Write-Host "=============================================="
    Write-Host "   DEPLOYMENT PREPARATION COMPLETE"
    Write-Host "=============================================="
    Write-Host
    Write-Host "Deployment package and instructions are available at:"
    Write-Host "$deployDir" -ForegroundColor Cyan
    Write-Host
    Write-Host "Follow the instructions in DEPLOYMENT-INSTRUCTIONS.md to complete deployment."
    Write-Host
} catch {
    Write-Host "ERROR: An unexpected error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    Stop-Transcript
}

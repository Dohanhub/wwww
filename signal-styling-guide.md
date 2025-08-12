# Signal Styling Integration Guide

This guide explains how to apply the Signal-inspired styling to all domains in your multi-domain website structure.

## Overview

The Signal-inspired styling provides clean, modern UI elements with a focus on:
- Minimalist design with purposeful whitespace
- High-contrast, readable typography
- Subtle animations and transitions
- Consistent component styling
- Accessibility-friendly color schemes

## Implementation Steps

### 1. Add the Signal CSS to Each Domain

For each domain (doganhub, doganconsult, ahmetdogan), update the HTML head section:

```html
<!-- Signal-Inspired Styling -->
<link rel="stylesheet" href="../shared/css/signal-inspired.css">
```

Add this link before any domain-specific CSS to ensure proper cascading.

### 2. Update Component Classes

Replace or add Signal-inspired classes to your HTML elements:

#### Before:
```html
<div class="feature-card">
    <div class="icon">
        <i class="fas fa-rocket"></i>
    </div>
    <h3>Feature Title</h3>
    <p>Feature description text here.</p>
</div>
```

#### After:
```html
<div class="signal-card signal-feature">
    <div class="signal-feature-icon">
        <i class="fas fa-rocket"></i>
    </div>
    <h3>Feature Title</h3>
    <p>Feature description text here.</p>
</div>
```

### 3. Update Button Styling

Replace standard buttons with Signal-styled buttons:

#### Before:
```html
<button class="btn btn-primary">Learn More</button>
```

#### After:
```html
<button class="signal-button">Learn More</button>
```

For secondary buttons:
```html
<button class="signal-button secondary">Learn More</button>
```

### 4. Hero Section Implementation

Update hero sections to use the Signal-inspired design:

```html
<section class="signal-hero">
    <div class="container">
        <h1>Your Compelling Headline</h1>
        <p>A clear and engaging description that explains your value proposition.</p>
        <div class="hero-actions">
            <button class="signal-button">Primary Action</button>
            <button class="signal-button secondary">Secondary Action</button>
        </div>
    </div>
</section>
```

### 5. Navigation Update

Transform your existing navigation into Signal-inspired navigation:

```html
<nav class="signal-nav container">
    <div class="signal-nav-logo">
        <img src="../shared/images/logo.svg" alt="Logo">
    </div>
    <div class="signal-nav-links">
        <a href="index.html" class="signal-nav-link active">Home</a>
        <a href="about.html" class="signal-nav-link">About</a>
        <a href="services.html" class="signal-nav-link">Services</a>
        <a href="contact.html" class="signal-nav-link">Contact</a>
    </div>
</nav>
```

### 6. Feature Grids

Implement Signal-style feature grids:

```html
<div class="signal-features container">
    <div class="signal-feature">
        <div class="signal-feature-icon">
            <i class="fas fa-shield-alt"></i>
        </div>
        <h3>Security First</h3>
        <p>Description of the security feature or benefit.</p>
    </div>
    <!-- More features -->
</div>
```

### 7. Footer Implementation

Apply Signal styling to footers:

```html
<footer class="signal-footer">
    <div class="container">
        <div class="signal-footer-grid">
            <div class="signal-footer-col">
                <h4>Company</h4>
                <div class="signal-footer-links">
                    <a href="#" class="signal-footer-link">About</a>
                    <a href="#" class="signal-footer-link">Team</a>
                    <a href="#" class="signal-footer-link">Careers</a>
                </div>
            </div>
            <!-- More footer columns -->
        </div>
        <div class="signal-copyright">
            © 2023 DoganHub. All rights reserved.
        </div>
    </div>
</footer>
```

## Domain-Specific Adjustments

While maintaining the Signal-inspired components, each domain should keep its unique color scheme and identity:

- **DoganHub**: Light theme with blue primary color
  ```css
  :root {
      --primary-color: #3b82f6;
      --primary-rgb: 59, 130, 246;
      --primary-hover: #2563eb;
  }
  ```

- **DoganConsult**: Modern theme with purple/indigo accents
  ```css
  :root {
      --primary-color: #6366f1;
      --primary-rgb: 99, 102, 241;
      --primary-hover: #4f46e5;
  }
  ```

- **AhmetDogan.info**: Professional theme with teal/green accents
  ```css
  :root {
      --primary-color: #0ea5e9;
      --primary-rgb: 14, 165, 233;
      --primary-hover: #0284c7;
  }
  ```

## Testing and Validation

After implementing these changes:

1. Test each page on desktop and mobile devices
2. Verify consistent spacing and typography
3. Check dark mode support (if enabled)
4. Validate accessibility with contrast checking tools

For any custom components not covered by the Signal styling, create additional classes following the same design principles.

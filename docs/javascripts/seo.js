/* SEO enhancements for IntuneManager documentation */

document.addEventListener('DOMContentLoaded', function() {
  addStructuredData();
  enhanceMetaTags();
  addOpenGraphTags();
  addTwitterCardTags();
  addCanonicalURL();
});

// Add JSON-LD structured data
function addStructuredData() {
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "IntuneManager",
    "applicationCategory": "Device Management Software",
    "operatingSystem": "macOS",
    "description": "A cross-platform companion app for Microsoft Intune administrators to triage devices, push applications, and review compliance reports.",
    "url": "https://github.com/rknightion/IntuneManager",
    "downloadUrl": "https://github.com/rknightion/IntuneManager",
    "softwareVersion": "latest",
    "programmingLanguage": "Swift",
    "license": "https://github.com/rknightion/IntuneManager/blob/main/LICENSE",
    "author": {
      "@type": "Person",
      "name": "Rob Knighton",
      "url": "https://github.com/rknightion"
    },
    "maintainer": {
      "@type": "Person",
      "name": "Rob Knighton",
      "url": "https://github.com/rknightion"
    },
    "applicationSubCategory": [
      "Endpoint Management",
      "Microsoft Intune",
      "Device Compliance",
      "Application Deployment"
    ],
    "offers": {
      "@type": "Offer",
      "price": "0",
      "priceCurrency": "USD"
    },
    "featureList": [
      "Dashboard overview with compliance insights",
      "Bulk application assignment workflows",
      "Device inventory with advanced filters",
      "Configuration profile management",
      "Intune audit log viewer",
      "Cross-platform SwiftUI interface"
    ]
  };

  const docData = {
    "@context": "https://schema.org",
    "@type": "TechArticle",
    "headline": document.title,
    "description": document.querySelector('meta[name="description"]')?.content || "IntuneManager documentation",
    "url": window.location.href,
    "datePublished": document.querySelector('meta[name="date"]')?.content,
    "dateModified": document.querySelector('meta[name="git-revision-date-localized"]')?.content,
    "author": {
      "@type": "Person",
      "name": "Rob Knighton"
    },
    "publisher": {
      "@type": "Organization",
      "name": "IntuneManager",
      "url": "https://github.com/rknightion/IntuneManager"
    },
    "mainEntityOfPage": {
      "@type": "WebPage",
      "@id": window.location.href
    },
    "articleSection": getDocumentationSection(),
    "keywords": getPageKeywords(),
    "about": {
      "@type": "SoftwareApplication",
      "name": "IntuneManager"
    }
  };

  const script1 = document.createElement('script');
  script1.type = 'application/ld+json';
  script1.textContent = JSON.stringify(structuredData);
  document.head.appendChild(script1);

  const script2 = document.createElement('script');
  script2.type = 'application/ld+json';
  script2.textContent = JSON.stringify(docData);
  document.head.appendChild(script2);
}

// Enhance existing meta tags
function enhanceMetaTags() {
  if (!document.querySelector('meta[name="robots"]')) {
    addMetaTag('name', 'robots', 'index, follow, max-snippet:-1, max-image-preview:large, max-video-preview:-1');
  }

  addMetaTag('name', 'language', 'en');
  addMetaTag('http-equiv', 'Content-Type', 'text/html; charset=utf-8');

  if (!document.querySelector('meta[name="viewport"]')) {
    addMetaTag('name', 'viewport', 'width=device-width, initial-scale=1');
  }

  const keywords = getPageKeywords();
  if (keywords) {
    addMetaTag('name', 'keywords', keywords);
  }

  if (isDocumentationPage()) {
    addMetaTag('name', 'article:tag', 'intune');
    addMetaTag('name', 'article:tag', 'endpoint-management');
    addMetaTag('name', 'article:tag', 'device-compliance');
    addMetaTag('name', 'article:tag', 'microsoft-graph');
  }
}

// Add Open Graph tags
function addOpenGraphTags() {
  const title = document.title || 'IntuneManager Documentation';
  const description = document.querySelector('meta[name="description"]')?.content ||
    'User guide for IntuneManager, a cross-platform companion app for Microsoft Intune administrators.';
  const url = window.location.href;
  const siteName = 'IntuneManager Documentation';

  addMetaTag('property', 'og:type', 'website');
  addMetaTag('property', 'og:site_name', siteName);
  addMetaTag('property', 'og:title', title);
  addMetaTag('property', 'og:description', description);
  addMetaTag('property', 'og:url', url);
  addMetaTag('property', 'og:locale', 'en_US');
  addMetaTag('property', 'og:image', 'https://m7kni.io/IntuneManager/assets/og-image.png');
  addMetaTag('property', 'og:image:width', '1200');
  addMetaTag('property', 'og:image:height', '630');
  addMetaTag('property', 'og:image:alt', 'IntuneManager - Microsoft Intune companion app');
}

// Add Twitter Card tags
function addTwitterCardTags() {
  const title = document.title || 'IntuneManager Documentation';
  const description = document.querySelector('meta[name="description"]')?.content ||
    'User guide for IntuneManager, a cross-platform companion app for Microsoft Intune administrators.';

  addMetaTag('name', 'twitter:card', 'summary_large_image');
  addMetaTag('name', 'twitter:title', title);
  addMetaTag('name', 'twitter:description', description);
  addMetaTag('name', 'twitter:image', 'https://m7kni.io/IntuneManager/assets/twitter-card.png');
  addMetaTag('name', 'twitter:creator', '@rknightion');
  addMetaTag('name', 'twitter:site', '@rknightion');
}

// Add canonical URL
function addCanonicalURL() {
  if (!document.querySelector('link[rel="canonical"]')) {
    const canonical = document.createElement('link');
    canonical.rel = 'canonical';
    canonical.href = window.location.href;
    document.head.appendChild(canonical);
  }
}

// Helper functions
function addMetaTag(attribute, name, content) {
  if (!document.querySelector(`meta[${attribute}="${name}"]`)) {
    const meta = document.createElement('meta');
    meta.setAttribute(attribute, name);
    meta.content = content;
    document.head.appendChild(meta);
  }
}

function getDocumentationSection() {
  const path = window.location.pathname;
  if (path.includes('/device-support/')) return 'Device Support';
  if (path.includes('/supported-entities/')) return 'Features';
  if (path.includes('/getting-started/')) return 'Onboarding';
  if (path.includes('/api-optimization/')) return 'Performance';
  if (path.includes('/architecture/')) return 'Architecture';
  if (path.includes('/faq/')) return 'FAQ';
  if (path.includes('/changelog/')) return 'Changelog';
  return 'Documentation';
}

function getPageKeywords() {
  const path = window.location.pathname;
  const content = document.body.textContent.toLowerCase();

  let keywords = ['intune', 'microsoft intune', 'endpoint management', 'device compliance', 'application deployment'];

  if (path.includes('/device-support/')) keywords.push('devices', 'platform support', 'compliance');
  if (path.includes('/supported-entities/')) keywords.push('features', 'assignments', 'reports');
  if (path.includes('/getting-started/')) keywords.push('setup', 'azure ad', 'msal');
  if (path.includes('/api-optimization/')) keywords.push('microsoft graph', 'performance', 'batching');
  if (path.includes('/architecture/')) keywords.push('swiftui', 'swiftdata', 'msal');
  if (path.includes('/faq/')) keywords.push('troubleshooting', 'support');

  if (content.includes('compliance')) keywords.push('compliance', 'policy');
  if (content.includes('bulk assignment')) keywords.push('assignments', 'deployment');
  if (content.includes('audit log')) keywords.push('audit', 'reporting');

  return keywords.join(', ');
}

function isDocumentationPage() {
  return !window.location.pathname.endsWith('/') ||
         window.location.pathname.includes('/docs/');
}

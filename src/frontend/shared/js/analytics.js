// Analytics tracking for Mossy Life
// Non-blocking, privacy-friendly analytics

(function() {
  'use strict';
  
  const API_ENDPOINT = 'https://qacegvdyd8.execute-api.us-west-2.amazonaws.com/prod/track';
  
  // Track page view on load
  function trackPageView() {
    const data = {
      event: 'pageView',
      page: window.location.pathname,
      referrer: document.referrer || 'direct'
    };
    
    sendAnalytics(data);
  }
  
  // Track Quantum Fiber referral link clicks
  function trackQuantumFiberClick(event) {
    const data = {
      event: 'quantumFiberClick',
      page: window.location.pathname,
      linkText: event.target.textContent.trim(),
      linkHref: event.target.href,
      linkId: event.target.id || 'unknown'
    };
    
    sendAnalytics(data);
  }
  
  // Track Amazon affiliate link clicks
  function trackAmazonClick(event) {
    const data = {
      event: 'amazonClick',
      page: window.location.pathname,
      linkText: event.target.textContent.trim(),
      linkHref: event.target.href
    };
    
    sendAnalytics(data);
  }
  
  // Send analytics data (fire and forget)
  function sendAnalytics(data) {
    // Use fetch instead of sendBeacon to avoid credentials issues
    fetch(API_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
      keepalive: true,
      credentials: 'omit',  // IMPORTANT: Don't send credentials
      mode: 'cors'          // IMPORTANT: Explicitly set CORS mode
    }).catch(function(error) {
      // Silently fail - don't break the page
      console.debug('Analytics error:', error);
    });
  }
  
  // Initialize tracking
  function init() {
    // Track page view
    trackPageView();
    
    // Track all Quantum Fiber CTA button clicks
    const quantumFiberButtons = document.querySelectorAll('.cta-button');
    quantumFiberButtons.forEach(function(button) {
      button.addEventListener('click', trackQuantumFiberClick);
    });
    
    // Track Amazon affiliate links
    const amazonLinks = document.querySelectorAll('a[href*="amazon.com"], a.amazon-link');
    amazonLinks.forEach(function(link) {
      link.addEventListener('click', trackAmazonClick);
    });
  }
  
  // Run after DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  
})();
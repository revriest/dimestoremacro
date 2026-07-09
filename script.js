// QR Code generation
document.addEventListener('DOMContentLoaded', function() {
    // Generate QR code for the website (will update with app store links later)
    const qrcodeElement = document.getElementById('qrcode');
    if (qrcodeElement && typeof QRCode !== 'undefined') {
        new QRCode(qrcodeElement, {
            text: 'https://baremacros.com',
            width: 128,
            height: 128,
            colorDark: '#0D0D0F',
            colorLight: '#ffffff',
            correctLevel: QRCode.CorrectLevel.H
        });
    }

    // Smooth scrolling for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            const href = this.getAttribute('href');
            if (href !== '#') {
                e.preventDefault();
                const target = document.querySelector(href);
                if (target) {
                    target.scrollIntoView({
                        behavior: 'smooth',
                        block: 'start'
                    });
                }
            }
        });
    });

    // Add scroll animation for nav
    let lastScroll = 0;
    const nav = document.querySelector('.nav');
    
    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;
        
        if (currentScroll <= 0) {
            nav.style.transform = 'translateY(0)';
            return;
        }
        
        if (currentScroll > lastScroll && currentScroll > 100) {
            // Scrolling down
            nav.style.transform = 'translateY(-100%)';
        } else {
            // Scrolling up
            nav.style.transform = 'translateY(0)';
        }
        
        lastScroll = currentScroll;
    });

    // Placeholder images for screenshots (replace with actual screenshots)
    const screenshots = [
        'screenshot-dashboard.jpg',
        'screenshot-search.jpg',
        'screenshot-settings.jpg',
        'screenshot-meals.jpg'
    ];

    // You'll need to add actual screenshot images to the repo
    // For now, the HTML references them directly
});
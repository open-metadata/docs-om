import { useEffect, useRef, useState } from 'react'
import './ReleaseCarousel.css'

export const ReleaseCarousel = () => {
    const AUTOPLAY_INTERVAL = 6000

    const SLIDES = [
        {
            header: 'OpenMetadata 2.0',
            image: '/public/images/release-2.0/modules/overview.png',
            alt: 'OpenMetadata 2.0 overview summary',
            text: (
                <>OpenMetadata 2.0 is a major release: a redesigned Explore page with <strong>Browse Estate</strong>, <strong>Context Center</strong> for reference content, first-class <strong>Tasks</strong> replacing suggestions and threads, <strong>Custom Intake Forms</strong> for governance workflows, a 3D <strong>Knowledge Graph</strong> for glossary exploration, <strong>Dynamic Sampling</strong> in the Profiler, and a cleaner landing page.</>
            ),
            link: '/v2.1.x-SNAPSHOT/releases/2.0-release',
        },
        {
            header: 'Explore Page',
            image: '/public/images/release-2.0/modules/explore-page.png',
            alt: 'Redesigned Explore page showing the Browse Estate panel, the query bar, and result cards',
            text: (
                <>The Explore page's left panel is now <strong>Browse Estate</strong>. Browsing a location no longer overwrites your filters, it stacks with them, with every active filter and browse level shown as a removable chip and no more <strong>Update</strong> button to click.</>
            ),
            link: '/v2.1.x-SNAPSHOT/deployment/upgrade/breaking-changes/discovery-and-search',
        },
        {
            header: 'Context Center',
            image: '/public/images/release-2.0/modules/context-center.png',
            alt: 'Context Center dashboard showing articles, documents, and memories',
            text: (
                <><strong>Knowledge Center</strong> is now <strong>Context Center</strong>, the single home for reference content in your catalog. Existing pages migrate automatically as <strong>Articles</strong>, and new <strong>Documents</strong> and a dashboard view make discovering and managing content across your org easier.</>
            ),
            link: '/v2.1.x-SNAPSHOT/releases/2.0-release#context-center',
        },
        {
            header: 'Home Page Experience',
            image: '/public/images/release-2.0/modules/landing-page.png',
            alt: 'Redesigned OpenMetadata 2.0 landing page',
            text: (
                <>The homepage has been redesigned with a cleaner navigation structure and more direct entry points into discovery, lineage, governance, and data quality, cutting the clicks needed to reach your most-used workflows.</>
            ),
            link: '/v2.1.x-SNAPSHOT/releases/2.0-release#landing-page',
        },
    ]

    const [index, setIndex] = useState(0)
    const [direction, setDirection] = useState('next')
    const [isPaused, setIsPaused] = useState(false)
    const [isLightboxOpen, setIsLightboxOpen] = useState(false)
    const timerRef = useRef(null)

    const slide = SLIDES[index]

    // Mounted directly on document.body (outside React's tree) so the overlay
    // covers the real viewport, regardless of any CSS container-query ancestor
    // on the homepage that would otherwise become a containing block for
    // `position: fixed` descendants too.
    useEffect(() => {
        if (!isLightboxOpen) return undefined

        // Defensive: clear out any stray overlay (e.g. left behind by a dev
        // hot-reload) so this effect never stacks a second one.
        document.querySelectorAll('.release-carousel-lightbox').forEach((el) => el.remove())

        const overlay = document.createElement('div')
        overlay.className = 'release-carousel-lightbox'
        overlay.setAttribute('role', 'presentation')

        const closeButton = document.createElement('button')
        closeButton.type = 'button'
        closeButton.className = 'release-carousel-lightbox-close'
        closeButton.setAttribute('aria-label', 'Close expanded image')
        closeButton.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" /></svg>'

        const image = document.createElement('img')
        image.src = slide.image
        image.alt = slide.alt
        image.className = 'release-carousel-lightbox-image'

        overlay.appendChild(closeButton)
        overlay.appendChild(image)
        document.body.appendChild(overlay)

        const close = () => setIsLightboxOpen(false)
        closeButton.addEventListener('click', close)

        const onKeyDown = (e) => {
            if (e.key === 'Escape') close()
        }
        document.addEventListener('keydown', onKeyDown)

        return () => {
            document.removeEventListener('keydown', onKeyDown)
            overlay.remove()
        }
    }, [isLightboxOpen, index])

    useEffect(() => {
        if (isPaused || isLightboxOpen) return undefined

        timerRef.current = setInterval(() => {
            setDirection('next')
            setIndex((prev) => (prev + 1) % SLIDES.length)
        }, AUTOPLAY_INTERVAL)

        return () => clearInterval(timerRef.current)
    }, [isPaused, isLightboxOpen, index])

    const goTo = (i) => {
        setDirection(i > index ? 'next' : 'prev')
        setIndex(i)
    }
    const goPrev = () => {
        setDirection('prev')
        setIndex((prev) => (prev - 1 + SLIDES.length) % SLIDES.length)
    }
    const goNext = () => {
        setDirection('next')
        setIndex((prev) => (prev + 1) % SLIDES.length)
    }

    return (
        <div
            className="release-banner release-carousel"
            onMouseEnter={() => setIsPaused(true)}
            onMouseLeave={() => setIsPaused(false)}
        >
            <div className="release-carousel-viewport">
                <div
                    className={`release-banner-content release-carousel-content slide-${direction}`}
                    key={index}
                >
                    <div>
                        <img
                            src={slide.image}
                            alt={slide.alt}
                            className="release-carousel-image"
                            role="button"
                            tabIndex={0}
                            onClick={() => setIsLightboxOpen(true)}
                            onKeyDown={(e) => {
                                if (e.key === 'Enter' || e.key === ' ') {
                                    e.preventDefault()
                                    setIsLightboxOpen(true)
                                }
                            }}
                            aria-label={`Expand image: ${slide.alt}`}
                        />
                    </div>

                    <div>
                        <div className="release-carousel-title-row">
                            <h2>{slide.header}</h2>
                            <span className="release-carousel-eyebrow">New Release</span>
                        </div>
                        <p>{slide.text}</p>
                        <a href={slide.link}>See what's new →</a>
                    </div>
                </div>
            </div>

            <button
                type="button"
                className="carousel-arrow carousel-arrow-prev"
                onClick={goPrev}
                aria-label="Previous update"
            >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <polyline points="15 6 9 12 15 18" />
                </svg>
            </button>
            <button
                type="button"
                className="carousel-arrow carousel-arrow-next"
                onClick={goNext}
                aria-label="Next update"
            >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <polyline points="9 6 15 12 9 18" />
                </svg>
            </button>

            <div className="carousel-dots">
                {SLIDES.map((s, i) => (
                    <button
                        type="button"
                        key={s.header}
                        className={`carousel-dot ${i === index ? 'active' : ''}`}
                        onClick={() => goTo(i)}
                        aria-label={`Go to ${s.header}`}
                    />
                ))}
            </div>
        </div>
    )
}

import { useEffect, useRef, useState } from 'react'
import './ReleaseCarousel.css'

export const ReleaseCarousel = () => {
    const AUTOPLAY_INTERVAL = 6000

    const SLIDES = [
        {
            header: 'OpenMetadata 2.1: AI Mode',
            image: '/public/images/release-2.1/modules/ai-mode.png',
            alt: 'AI mode Explore page with the new left navigation',
            text: (
                <>AI mode is the primary experience in OpenMetadata 2.1, and Classic mode is deprecated. The release adds richer <strong>Data Quality</strong> and <strong>governance</strong>, including failure thresholds and <strong>change requests</strong>, a larger <strong>Context Center</strong>, a complete <strong>Metrics</strong> entity, <strong>hierarchical lineage maps</strong>, and <strong>Ontology Explorer</strong> with a knowledge graph. It also brings seven new connectors and many improvements to existing ones.</>
            ),
            link: '/v2.1.x/releases',
            linkText: "See what's new →",
        },
        {
            header: 'New Profile Menu',
            image: '/public/images/release-2.1/modules/profile-menu.png',
            alt: 'Profile menu showing domain scope, active persona, Settings, Appearance, and AI mode',
            text: (
                <>One menu for your account: set your <strong>Domain scope</strong>, <strong>Switch Persona</strong>, open <strong>My Data &amp; Following</strong>, change <strong>Language</strong> and <strong>Appearance</strong>, or jump to <strong>Settings</strong>.</>
            ),
            link: '/v2.1.x/how-to-guides/admin-guide/profile#profile-menu',
        },
        {
            header: 'Default Persona',
            image: '/public/images/release-2.1/modules/default-persona.png',
            alt: 'Persona page with the Set as Default button in the header',
            text: (
                <>Admins can make any persona the organization default with <strong>Set as Default</strong>, right from the persona page header. Only one persona can be the default at a time.</>
            ),
            link: '/v2.1.x/how-to-guides/admin-guide/persona-landing-page-customization/defining-persona',
        },
        {
            header: 'New Settings Page',
            image: '/public/images/release-2.1/modules/settings-page.png',
            alt: 'Redesigned Settings page with Account, Administration, Features, and Workspace sections',
            text: (
                <>Settings now opens as one window with a left menu grouped into <strong>Account</strong>, <strong>Administration</strong>, <strong>Features</strong>, and <strong>Workspace</strong>. Manage your profile, access control, bots, personas, and custom properties without leaving it.</>
            ),
            link: '/v2.1.x/how-to-guides/admin-guide/profile#settings-modal',
        },
        {
            header: 'Personal Preferences',
            image: '/public/images/release-2.1/modules/appearance.png',
            alt: 'Preferences page with the Light, Dark, and System theme switch',
            text: (
                <>Pick <strong>Light</strong>, <strong>Dark</strong>, or <strong>System</strong> under <strong>Preferences</strong> &gt; <strong>Theme</strong>, and turn on a <strong>Compact Sidebar</strong> if you want more room.</>
            ),
            link: '/v2.1.x/how-to-guides/admin-guide/profile#your-preferences',
        },
        {
            header: 'Hierarchical Lineage Maps',
            image: '/public/images/how-to-guides/lineage/lineage-map-overview.png',
            alt: 'Hierarchical lineage map at the Service Level',
            text: (
                <>The <strong>Lineage</strong> page now opens as a map you can zoom into. Start with an overview of your services and drill down one level at a time, all the way to individual fields, instead of reading one large graph of every table.</>
            ),
            link: '/v2.1.x/how-to-guides/data-lineage/explore',
        },
    ]

    const [index, setIndex] = useState(0)
    const [direction, setDirection] = useState('next')
    const [isPaused, setIsPaused] = useState(false)
    const [isLightboxOpen, setIsLightboxOpen] = useState(false)
    const timerRef = useRef(null)
    const imageTriggerRef = useRef(null)

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

        const previousActiveElement = document.activeElement instanceof HTMLElement ? document.activeElement : null
        const overlay = document.createElement('div')
        overlay.className = 'release-carousel-lightbox'
        overlay.setAttribute('role', 'dialog')
        overlay.setAttribute('aria-modal', 'true')
        overlay.setAttribute('aria-label', `Expanded image: ${slide.alt}`)
        overlay.tabIndex = -1

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
        closeButton.focus()

        const onKeyDown = (e) => {
            if (e.key === 'Escape') close()
            if (e.key === 'Tab') {
                e.preventDefault()
                closeButton.focus()
            }
        }
        overlay.addEventListener('keydown', onKeyDown)

        return () => {
            overlay.removeEventListener('keydown', onKeyDown)
            closeButton.removeEventListener('click', close)
            overlay.remove()
            if (previousActiveElement?.isConnected) {
                previousActiveElement.focus()
            } else {
                imageTriggerRef.current?.focus()
            }
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
            onFocus={() => setIsPaused(true)}
            onBlur={(e) => {
                if (!e.currentTarget.contains(e.relatedTarget)) setIsPaused(false)
            }}
            onTouchStart={() => setIsPaused(true)}
            onTouchEnd={() => setIsPaused(false)}
            onTouchCancel={() => setIsPaused(false)}
        >
            <div className="release-carousel-viewport">
                <div
                    className={`release-banner-content release-carousel-content slide-${direction}`}
                    key={slide.header}
                >
                    <div>
                        <img
                            src={slide.image}
                            alt={slide.alt}
                            className="release-carousel-image"
                            ref={imageTriggerRef}
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
                            <span className="release-carousel-eyebrow">Release 2.1</span>
                        </div>
                        <p>{slide.text}</p>
                        <a href={slide.link}>{slide.linkText || 'Learn more →'}</a>
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
                        className={['carousel-dot', i === index ? 'active' : ''].filter(Boolean).join(' ')}
                        onClick={() => goTo(i)}
                        aria-label={`Go to ${s.header}`}
                    />
                ))}
            </div>
        </div>
    )
}

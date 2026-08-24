import { useEffect, useMemo, useRef, useState } from 'react'
import './ConnectorFilter.css'

export const ConnectorFilter = () => {
    const ALL = 'all'
    const anchorRef = useRef(null)
    const [sections, setSections] = useState([])
    const [serviceType, setServiceType] = useState(ALL)
    const [service, setService] = useState(ALL)
    const [openField, setOpenField] = useState(null)
    const [search, setSearch] = useState('')

    useEffect(() => {
        // Mintlify's MDX compiler hoists this component to be a sibling of
        // `.connector-page` rather than nesting it, so look it up directly
        // instead of walking ancestors from this component's own root node.
        const page = document.querySelector('.connector-page')
        if (!page) return

        const discover = () => {
            const headings = Array.from(page.querySelectorAll(':scope > h2'))
            return headings
                .map((heading) => {
                    const cards = []
                    let sibling = heading.nextElementSibling
                    while (sibling && sibling.tagName !== 'H2') {
                        sibling.querySelectorAll('a[href]').forEach((anchor) => {
                            const href = anchor.getAttribute('href')
                            const name = anchor.textContent.replace(/PROD$|BETA$/, '').trim()
                            const el = anchor.closest('.card') || anchor
                            if (href && name) cards.push({ href, name, el })
                        })
                        sibling = sibling.nextElementSibling
                    }
                    const type = heading.textContent.replace(/[​-‍﻿]/g, '').trim()
                    return { type, headingEl: heading, cards }
                })
                .filter((section) => section.cards.length > 0)
        }

        // The CardGroup snippets for each category hydrate asynchronously, so the
        // links aren't necessarily attached yet on mount. Keep re-scanning until
        // the connector list stops changing.
        let frame = null
        const rescan = () => {
            frame = null
            setSections(discover())
        }
        rescan()

        const observer = new MutationObserver(() => {
            if (frame) cancelAnimationFrame(frame)
            frame = requestAnimationFrame(rescan)
        })
        observer.observe(page, { childList: true, subtree: true })

        return () => {
            observer.disconnect()
            if (frame) cancelAnimationFrame(frame)
        }
    }, [])

    useEffect(() => {
        const query = search.trim().toLowerCase()

        sections.forEach((section) => {
            const typeMatches = serviceType === ALL || section.type === serviceType
            let visibleCount = 0

            section.cards.forEach(({ href, name, el }) => {
                const visible = typeMatches
                    && (service === ALL || href === service)
                    && (!query || name.toLowerCase().includes(query))
                el.style.display = visible ? '' : 'none'
                if (visible) visibleCount += 1
            })

            section.headingEl.style.display = visibleCount > 0 ? '' : 'none'
        })
    }, [sections, serviceType, service, search])

    useEffect(() => {
        // Selecting a service scrolls its card into view, which can carry the
        // filter box up under the site's sticky header. Pin it just below the
        // header (measured live, since a promo banner changes its height).
        const updateOffset = () => {
            const header = document.querySelector('header')
            const height = header?.getBoundingClientRect().height ?? 0
            if (anchorRef.current) anchorRef.current.style.top = `${height}px`
        }
        updateOffset()
        window.addEventListener('resize', updateOffset)
        return () => window.removeEventListener('resize', updateOffset)
    }, [])

    useEffect(() => {
        if (!openField) return

        const handlePointerDown = (event) => {
            if (anchorRef.current && !anchorRef.current.contains(event.target)) {
                setOpenField(null)
            }
        }
        const handleKeyDown = (event) => {
            if (event.key === 'Escape') setOpenField(null)
        }

        document.addEventListener('mousedown', handlePointerDown)
        document.addEventListener('keydown', handleKeyDown)
        return () => {
            document.removeEventListener('mousedown', handlePointerDown)
            document.removeEventListener('keydown', handleKeyDown)
        }
    }, [openField])

    const visibleSections = useMemo(() => {
        return serviceType === ALL
            ? sections
            : sections.filter((section) => section.type === serviceType)
    }, [sections, serviceType])

    const selectedServiceName = useMemo(() => {
        if (service === ALL) return 'All Services'
        for (const section of sections) {
            const card = section.cards.find((c) => c.href === service)
            if (card) return card.name
        }
        return 'All Services'
    }, [service, sections])

    const selectServiceType = (value) => {
        setServiceType(value)
        setService(ALL)
        setOpenField(null)
    }

    const selectService = (value) => {
        setService(value)
        setSearch('')
        setOpenField(null)
        if (value === ALL) return

        const owningSection = sections.find((section) => section.cards.some((card) => card.href === value))
        const card = owningSection?.cards.find((card) => card.href === value)
        if (owningSection) setServiceType(owningSection.type)
        requestAnimationFrame(() => {
            card?.el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        })
    }

    const handleSearchChange = (event) => {
        setSearch(event.target.value)
        setService(ALL)
    }

    const handleReset = () => {
        setServiceType(ALL)
        setService(ALL)
        setSearch('')
        setOpenField(null)
    }

    const hasActiveFilter = serviceType !== ALL || service !== ALL || search.trim() !== ''

    // Rendered via plain function calls (not JSX tags) — this page's MDX/JSX
    // loader only recognizes the single exported component and doesn't resolve
    // capitalized JSX tags for sibling helper components defined in this file.
    const renderChevron = (open) => (
        <svg
            className={`connector-filter-chevron${open ? ' connector-filter-chevron-open' : ''}`}
            width="14"
            height="14"
            viewBox="0 0 16 16"
            fill="none"
        >
            <path d="M4 6l4 4 4-4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
    )

    const renderDropdown = ({ label, id, isOpen, onToggle, displayValue, items }) => (
        <div className="connector-filter-field">
            <label htmlFor={id}>{label}</label>
            <div className="connector-filter-dropdown">
                <button
                    type="button"
                    id={id}
                    className="connector-filter-trigger"
                    aria-expanded={isOpen}
                    aria-haspopup="listbox"
                    onClick={onToggle}
                >
                    <span>{displayValue}</span>
                    {renderChevron(isOpen)}
                </button>
                {isOpen && (
                    <ul className="connector-filter-menu" role="listbox">
                        {items}
                    </ul>
                )}
            </div>
        </div>
    )

    const typeItems = [
        <li
            key={ALL}
            role="option"
            aria-selected={serviceType === ALL}
            className={serviceType === ALL ? 'active' : ''}
            onClick={() => selectServiceType(ALL)}
        >
            All Service Types
        </li>,
        ...sections.map((section) => (
            <li
                key={section.type}
                role="option"
                aria-selected={serviceType === section.type}
                className={serviceType === section.type ? 'active' : ''}
                onClick={() => selectServiceType(section.type)}
            >
                {section.type}
            </li>
        )),
    ]

    const serviceItems = [
        <li
            key={ALL}
            role="option"
            aria-selected={service === ALL}
            className={service === ALL ? 'active' : ''}
            onClick={() => selectService(ALL)}
        >
            All Services
        </li>,
        ...(serviceType === ALL
            ? visibleSections.flatMap((section) => [
                <li key={section.type} className="connector-filter-group-label" role="presentation">
                    {section.type}
                </li>,
                ...[...section.cards]
                    .sort((a, b) => a.name.localeCompare(b.name))
                    .map((card) => (
                        <li
                            key={card.href}
                            role="option"
                            aria-selected={service === card.href}
                            className={service === card.href ? 'active' : ''}
                            onClick={() => selectService(card.href)}
                        >
                            {card.name}
                        </li>
                    )),
            ])
            : (visibleSections[0]?.cards ?? [])
                .slice()
                .sort((a, b) => a.name.localeCompare(b.name))
                .map((card) => (
                    <li
                        key={card.href}
                        role="option"
                        aria-selected={service === card.href}
                        className={service === card.href ? 'active' : ''}
                        onClick={() => selectService(card.href)}
                    >
                        {card.name}
                    </li>
                ))),
    ]

    return (
        <div className="connector-filter" ref={anchorRef}>
            <div className="connector-filter-row">
                <div className="connector-filter-field connector-filter-search-field">
                    <label htmlFor="connector-filter-search">Search</label>
                    <div className="connector-filter-search">
                        <svg width="14" height="14" viewBox="0 0 16 16" fill="none">
                            <circle cx="7" cy="7" r="5" stroke="currentColor" strokeWidth="1.6" />
                            <path d="M11 11l3.5 3.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
                        </svg>
                        <input
                            id="connector-filter-search"
                            type="text"
                            placeholder="Search connectors..."
                            value={search}
                            onChange={handleSearchChange}
                        />
                    </div>
                </div>

                {renderDropdown({
                    label: 'Service Type',
                    id: 'connector-filter-type',
                    isOpen: openField === 'type',
                    onToggle: () => setOpenField(openField === 'type' ? null : 'type'),
                    displayValue: serviceType === ALL ? 'All Service Types' : serviceType,
                    items: typeItems,
                })}

                {renderDropdown({
                    label: 'Service',
                    id: 'connector-filter-service',
                    isOpen: openField === 'service',
                    onToggle: () => setOpenField(openField === 'service' ? null : 'service'),
                    displayValue: selectedServiceName,
                    items: serviceItems,
                })}

                {hasActiveFilter && (
                    <button type="button" className="connector-filter-reset" onClick={handleReset}>
                        Reset
                    </button>
                )}
            </div>
        </div>
    )
}

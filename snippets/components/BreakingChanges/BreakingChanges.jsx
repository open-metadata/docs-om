import './BreakingChanges.css';

export const BreakingChanges = ({ children }) => {
    return (
        <div className="breaking-changes-container">
            <h2 className="breaking-changes-header">
                <svg className="breaking-changes-icon" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/>
                    <line x1="12" y1="9" x2="12" y2="13"/>
                    <line x1="12" y1="17" x2="12.01" y2="17"/>
                </svg>
                <span className="breaking-changes-title">Breaking Changes</span>
            </h2>
            <div className="breaking-changes-content">
                {children}
            </div>
        </div>
    )
}

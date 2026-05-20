export const CodeLayout = ({ title, description, children }) => (
  <div className="code-layout">
    {(title || description) && (
      <div className="code-layout-header">
        {title && <h3>{title}</h3>}
        {description && <div>{description}</div>}
      </div>
    )}
    {children}
  </div>
);

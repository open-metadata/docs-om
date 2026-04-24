import React from 'react';

export const CodeLayout = ({ title, description, children }) => (
  <div className="code-layout">
    <div className="code-layout-content">
      {title && <h4>{title}</h4>}
      {description}
    </div>
    <div className="code-layout-code">{children}</div>
  </div>
);

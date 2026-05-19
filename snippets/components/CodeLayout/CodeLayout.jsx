import React from 'react';
import './CodeLayout.css';

export const CodeLayout = ({ title, description, children }) => {
  return (
    <div className="code-layout">
      <div>
        {title && (
          <h2>{title}</h2>
        )}
        {description && (
          <div>
            {description}
          </div>
        )}
      </div>

      <div className="code-layout-sticky">
        {children}
      </div>
    </div>
  );
};

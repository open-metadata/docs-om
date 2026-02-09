export const CollateOnly = ({ children }) => {
  // Build-time conditional rendering
  // COLLATE_BUILD is set at build time, tree-shaken by bundler
  const IS_COLLATE = process.env.COLLATE_BUILD === 'true';
  
  if (!IS_COLLATE) {
    return null; // Removed from build in OSS
  }
  
  return <>{children}</>;
};

export default CollateOnly;

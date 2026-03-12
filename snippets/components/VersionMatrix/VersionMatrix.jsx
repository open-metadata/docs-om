import "./VersionMatrix.css";

export const VersionMatrix = () => {
    const data = [
        { service: "Mysql", version: "8.0.8", updated: true },
        { service: "Postgres", version: "1.15.0" },
        { service: "OpenSearch", version: "3.2.0" },
        { service: "ElasticSearch", version: "9.3.0" },
    ]
    return (
        <div className="vm-wrapper">
            <table className="vm-table">
                <thead>
                    <tr className="vm-header-row">
                        <th className="vm-th">Service</th>
                        <th className="vm-th">Minimum Version</th>
                    </tr>
                </thead>
                <tbody>
                    {data.map((row, i) => (
                        <tr key={i} className={i % 2 === 0 ? "vm-row-even" : "vm-row-odd"}>
                            <td className={`vm-td${row.updated ? " vm-td-updated" : ""}`}>
                                {row.service}
                            </td>
                            <td className={`vm-td${row.updated ? " vm-td-updated" : ""}`}>
                                {row.version}
                                {row.updated && (
                                    <span className="vm-updated-badge"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" className="vm-badge-icon"><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z" /></svg>Minimum version updated</span>
                                )}
                            </td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
};

import { useMemo, useState } from 'react'
import './Integrations.css'

export const Integrations = () => {
    const INTEGRATION_SERVICES = [
        {
            connector: 'API',
            services: [
                {
                    name: 'REST',
                    image: '/public/images/connectors/rest.webp',
                    link: '/connectors/api/rest',
                },
            ],
        },
        {
            connector: 'Database',
            services: [
                {
                    name: 'Athena',
                    image: '/public/images/connectors/athena.webp',
                    link: '/connectors/database/athena',
                },
                {
                    name: 'Azure SQL',
                    image: '/public/images/connectors/azuresql.webp',
                    link: '/connectors/database/azuresql',
                },
                {
                    name: 'BigQuery',
                    image: '/public/images/connectors/bigquery.webp',
                    link: '/connectors/database/bigquery',
                },
                {
                    name: 'BigTable',
                    image: '/public/images/connectors/big-table.webp',
                    link: '/connectors/database/bigtable',
                },
                {
                    name: 'Cassandra',
                    image: '/public/images/connectors/cassandra.webp',
                    link: '/connectors/database/cassandra',
                },
                {
                    name: 'ClickHouse',
                    image: '/public/images/connectors/clickhouse.webp',
                    link: '/connectors/database/clickhouse',
                },
                {
                    name: 'Cockroach',
                    image: '/public/images/connectors/cockroach.png',
                    link: '/connectors/database/cockroach',
                },
                {
                    name: 'Couchbase',
                    image: '/public/images/connectors/couchbase.webp',
                    link: '/connectors/database/couchbase',
                },
                {
                    name: 'Delta Lake',
                    image: '/public/images/connectors/delta-lake.webp',
                    link: '/connectors/database/deltalake',
                },
                {
                    name: 'Druid',
                    image: '/public/images/connectors/druid.webp',
                    link: '/connectors/database/druid',
                },
                {
                    name: 'S3 Datalake',
                    image: '/public/images/connectors/amazon-s3.webp',
                    link: '/connectors/database/s3-datalake',
                },
                {
                    name: 'ADLS Datalake',
                    image: '/public/images/connectors/adls.webp',
                    link: '/connectors/database/adls-datalake',
                },
                {
                    name: 'GCS Datalake',
                    image: '/public/images/connectors/gcs.webp',
                    link: '/connectors/database/gcs-datalake',
                },
                {
                    name: 'Databricks',
                    image: '/public/images/connectors/databrick.webp',
                    link: '/connectors/database/databricks',
                },
                {
                    name: 'DB2',
                    image: '/public/images/connectors/ibmdb2.webp',
                    link: '/connectors/database/db2',
                },
                {
                    name: 'dbt',
                    image: '/public/images/connectors/dbtcloud.webp',
                    link: '/connectors/pipeline/dbtcloud',
                },
                {
                    name: 'Domo',
                    image: '/public/images/connectors/domo.webp',
                    link: '/connectors/database/domo-database',
                },
                {
                    name: 'Doris',
                    image: '/public/images/connectors/doris.png',
                    link: '/connectors/database/doris',
                },
                {
                    name: 'DynamoDB',
                    image: '/public/images/connectors/dynamodb.webp',
                    link: '/connectors/database/dynamodb',
                },
                {
                    name: 'Epic',
                    image: '/public/images/connectors/epic.png',
                    link: '/connectors/database/epic',
                },
                {
                    name: 'Exasol',
                    image: '/public/images/connectors/exasol.webp',
                    link: '/connectors/database/exasol',
                },
                {
                    name: 'Glue',
                    image: '/public/images/connectors/glue.webp',
                    link: '/connectors/database/glue',
                },
                {
                    name: 'Greenplum',
                    image: '/public/images/connectors/greenplum.webp',
                    link: '/connectors/database/greenplum',
                },
                {
                    name: 'Hive',
                    image: '/public/images/connectors/hive.webp',
                    link: '/connectors/database/hive',
                },
                {
                    name: 'Iceberg',
                    image: '/public/images/connectors/iceberg.webp',
                    link: '/connectors/database/iceberg',
                },
                {
                    name: 'Impala',
                    image: '/public/images/connectors/impala.webp',
                    link: '/connectors/database/impala',
                },
                {
                    name: 'MariaDB',
                    image: '/public/images/connectors/mariadb.webp',
                    link: '/connectors/database/mariadb',
                },
                {
                    name: 'MongoDB',
                    image: '/public/images/connectors/mongodb.webp',
                    link: '/connectors/database/mongodb',
                },
                {
                    name: 'MSSQL',
                    image: '/public/images/connectors/mssql.webp',
                    link: '/connectors/database/mssql',
                },
                {
                    name: 'MySQL',
                    image: '/public/images/connectors/sql.webp',
                    link: '/connectors/database/mysql',
                },
                {
                    name: 'Oracle',
                    image: '/public/images/connectors/oracle.webp',
                    link: '/connectors/database/oracle',
                },
                {
                    name: 'PostgreSQL',
                    image: '/public/images/connectors/post.webp',
                    link: '/connectors/database/postgres',
                },
                {
                    name: 'Presto',
                    image: '/public/images/connectors/presto.webp',
                    link: '/connectors/database/presto',
                },
                {
                    name: 'Redshift',
                    image: '/public/images/connectors/redshift.webp',
                    link: '/connectors/database/redshift',
                },
                {
                    name: 'Salesforce',
                    image: '/public/images/connectors/salesforce.webp',
                    link: '/connectors/database/salesforce',
                },
                {
                    name: 'SAP ERP',
                    image: '/public/images/connectors/sap-erp.png',
                    link: '/connectors/database/sap-erp',
                },
                {
                    name: 'SAP HANA',
                    image: '/public/images/connectors/sap-hana.png',
                    link: '/connectors/database/sap-hana',
                },
                {
                    name: 'Snowflake',
                    image: '/public/images/connectors/snowflakes.webp',
                    link: '/connectors/database/snowflake',
                },
                {
                    name: 'ServiceNow',
                    image: '/public/images/connectors/servicenow.png',
                    link: '/connectors/database/servicenow',
                },
                {
                    name: 'SingleStore',
                    image: '/public/images/connectors/singlestore.webp',
                    link: '/connectors/database/singlestore',
                },
                {
                    name: 'Synapse',
                    image: '/public/images/connectors/synapse.webp',
                    link: '/connectors/database/synapse',
                },
                {
                    name: 'Teradata',
                    image: '/public/images/connectors/teradata.webp',
                    link: '/connectors/database/teradata',
                },
                {
                    name: 'TimescaleDB',
                    image: '/public/images/connectors/timescale.webp',
                    link: '/connectors/database/timescale',
                },
                {
                    name: 'Trino',
                    image: '/public/images/connectors/trino.webp',
                    link: '/connectors/database/trino',
                },
                {
                    name: 'Unity Catalog',
                    image: '/public/images/connectors/databrick.webp',
                    link: '/connectors/database/unity-catalog',
                },
                {
                    name: 'Vertica',
                    image: '/public/images/connectors/vertica.webp',
                    link: '/connectors/database/vertica',
                },
                {
                    name: 'Pinot',
                    image: '/public/images/connectors/pinot.webp',
                    link: '/connectors/database/pinotdb',
                },
                {
                    name: 'SAS',
                    image: '/public/images/connectors/sas.webp',
                    link: '/connectors/database/sas',
                },
                {
                    name: 'SQL Lite',
                    image: '/public/images/connectors/sqlite.webp',
                    link: '/connectors/database/sqlite',
                },
                {
                    name: 'SSAS',
                    image: '/public/images/connectors/ssas.png',
                    link: '/connectors/database/ssas',
                },
            ],
        },
        {
            connector: 'Messaging',
            services: [
                {
                    name: 'Kafka',
                    image: '/public/images/connectors/kafka.webp',
                    link: '/connectors/messaging/kafka',
                },
                {
                    name: 'Redpanda',
                    image: '/public/images/connectors/redpanda.webp',
                    link: '/connectors/messaging/redpanda',
                },
                {
                    name: 'Kinesis',
                    image: '/public/images/connectors/kinesis.webp',
                    link: '/connectors/messaging/kinesis',
                },
            ],
        },
        {
            connector: 'Dashboard',
            services: [
                {
                    name: 'Lightdash',
                    image: '/public/images/connectors/lightdash.webp',
                    link: '/connectors/dashboard/lightdash',
                },
                {
                    name: 'Grafana',
                    image: '/public/images/connectors/grafana.png',
                    link: '/connectors/dashboard/grafana',
                },
                {
                    name: 'Hex',
                    image: '/public/images/connectors/hex.webp',
                    link: '/connectors/dashboard/hex',
                },
                {
                    name: 'Looker',
                    image: '/public/images/connectors/looker.webp',
                    link: '/connectors/dashboard/looker',
                },
                {
                    name: 'Metabase',
                    image: '/public/images/connectors/metabase.webp',
                    link: '/connectors/dashboard/metabase',
                },
                {
                    name: 'MicroStrategy',
                    image: '/public/images/connectors/microstrategy.webp',
                    link: '/connectors/dashboard/microstrategy',
                },
                {
                    name: 'Mode',
                    image: '/public/images/connectors/mode.webp',
                    link: '/connectors/dashboard/mode',
                },
                {
                    name: 'Power BI',
                    image: '/public/images/connectors/power-bi.webp',
                    link: '/connectors/dashboard/powerbi',
                },
                {
                    name: 'PowerBI Report Server',
                    image: '/public/images/connectors/power-bi.webp',
                    link: '/connectors/dashboard/powerbireportserver',
                },
                {
                    name: 'Redash',
                    image: '/public/images/connectors/redash.webp',
                    link: '/connectors/dashboard/redash',
                },
                {
                    name: 'Sigma',
                    image: '/public/images/connectors/sigma.webp',
                    link: '/connectors/dashboard/sigma',
                },
                {
                    name: 'Superset',
                    image: '/public/images/connectors/superset.webp',
                    link: '/connectors/dashboard/superset',
                },
                {
                    name: 'Tableau',
                    image: '/public/images/connectors/tableau.webp',
                    link: '/connectors/dashboard/tableau',
                },
                {
                    name: 'ThoughtSpot',
                    image: '/public/images/connectors/thoughtspot.webp',
                    link: '/connectors/dashboard/thoughtspot',
                },
                {
                    name: 'Qlik Cloud',
                    image: '/public/images/connectors/qlikcloud.webp',
                    link: '/connectors/dashboard/qlikcloud',
                },
                {
                    name: 'Qlik Sense',
                    image: '/public/images/connectors/qlik-sense.webp',
                    link: '/connectors/dashboard/qliksense',
                },
                {
                    name: 'QuickSight',
                    image: '/public/images/connectors/quicksight.webp',
                    link: '/connectors/dashboard/quicksight',
                },
            ],
        },
        {
            connector: 'Pipeline',
            services: [
                {
                    name: 'Airflow',
                    image: '/public/images/connectors/airflow.webp',
                    link: '/connectors/pipeline/airflow',
                },
                {
                    name: 'Airbyte',
                    image: '/public/images/connectors/airbyte.webp',
                    link: '/connectors/pipeline/airbyte',
                },
                {
                    name: 'Dagster',
                    image: '/public/images/connectors/dagster.webp',
                    link: '/connectors/pipeline/dagster',
                },
                {
                    name: 'Databricks Pipeline',
                    image: '/public/images/connectors/databrick.webp',
                    link: '/connectors/pipeline/databricks-pipeline',
                },
                {
                    name: 'Azure Data Factory',
                    image: '/public/images/connectors/datafactory.png',
                    link: '/connectors/pipeline/datafactory',
                },
                {
                    name: 'dbt Cloud',
                    image: '/public/images/connectors/dbtcloud.webp',
                    link: '/connectors/pipeline/dbtcloud',
                },
                {
                    name: 'Fivetran',
                    image: '/public/images/connectors/fivetran.webp',
                    link: '/connectors/pipeline/fivetran',
                },
                {
                    name: 'Flink',
                    image: '/public/images/connectors/flink.png',
                    link: '/connectors/pipeline/flink',
                },
                {
                    name: 'Matillion',
                    image: '/public/images/connectors/matillion.png',
                    link: '/connectors/pipeline/matillion',
                },
                {
                    name: 'NiFi',
                    image: '/public/images/connectors/apachenifi.webp',
                    link: '/connectors/pipeline/nifi',
                },
                {
                    name: 'OpenLineage',
                    image: '/public/images/connectors/openlineage.png',
                    link: '/connectors/pipeline/openlineage',
                },
                {
                    name: 'Snowplow',
                    image: '/public/images/connectors/snowplow.png',
                    link: '/connectors/pipeline/snowplow',
                },
                {
                    name: 'Spline',
                    image: '/public/images/connectors/spline.webp',
                    link: '/connectors/pipeline/spline',
                },
                {
                    name: 'Stitch',
                    image: '/public/images/connectors/stitch.png',
                    link: '/connectors/pipeline/stitch',
                },
                {
                    name: 'KinesisFirehose',
                    image: '/public/images/connectors/kinesis-firehose.webp',
                    link: '/connectors/pipeline/kinesis-firehose',
                },
                {
                    name: 'Wherescape',
                    image: '/public/images/connectors/wherescape.png',
                    link: '/connectors/pipeline/wherescape',
                },
                {
                    name: 'SSIS',
                    image: '/public/images/connectors/ssis.webp',
                    link: '/connectors/pipeline/ssis',
                },
            ],
        },
        {
            connector: 'ML Model',
            services: [
                {
                    name: 'MLflow',
                    image: '/public/images/connectors/mlflow.webp',
                    link: '/connectors/ml-model/mlflow',
                },
                {
                    name: 'SageMaker',
                    image: '/public/images/connectors/sagemaker.webp',
                    link: '/connectors/ml-model/sagemaker',
                },
                {
                    name: 'VertexAI',
                    image: '/public/images/connectors/vertexai.png',
                    link: '/connectors/ml-model/vertexai',
                },
            ],
        },
        {
            connector: 'Search',
            services: [
                {
                    name: 'Elasticsearch',
                    image: '/public/images/connectors/elasticsearch.webp',
                    link: '/connectors/search/elasticsearch',
                },
                {
                    name: 'OpenSearch',
                    image: '/public/images/connectors/opensearch.webp',
                    link: '/connectors/search/opensearch',
                },
            ],
        },
        {
            connector: 'Storage',
            services: [
                {
                    name: 'ADLS',
                    image: '/public/images/connectors/adls.webp',
                    link: '/connectors/storage/adls',
                },
                {
                    name: 'GCS',
                    image: '/public/images/connectors/gcs.webp',
                    link: '/connectors/storage/gcs',
                },
                {
                    name: 'S3 Storage',
                    image: '/public/images/connectors/amazon-s3.webp',
                    link: '/connectors/storage/s3',
                },
            ],
        },
        {
            connector: 'Metadata',
            services: [
                {
                    name: 'Alation',
                    image: '/public/images/connectors/alation.webp',
                    link: '/connectors/metadata/alation',
                },
                {
                    name: 'AlationSink',
                    image: '/public/images/connectors/alation.webp',
                    link: '/connectors/metadata/alationsink',
                },
                {
                    name: 'Atlas',
                    image: '/public/images/connectors/atlas.webp',
                    link: '/connectors/metadata/atlas',
                },
                {
                    name: 'Collibra',
                    image: '/public/images/connectors/collibra.webp',
                    link: '/connectors/metadata/collibra',
                },
            ],
        },
        {
            connector: 'Security',
            services: [
                {
                    name: 'Ranger',
                    image: '/public/images/connectors/ranger.webp',
                    link: '/connectors/security/ranger',
                },
            ],
        },
    ]
    const allServices = useMemo(() => {
        const map = new Map()
        INTEGRATION_SERVICES.forEach((category) => {
            category.services.forEach((service) => {
                map.set(service.name, service)
            })
        })
        return Array.from(map.values()).sort((a, b) =>
            a.name.localeCompare(b.name)
        )
    }, [])

    const [selectedTab, setSelectedTab] = useState('All Connectors')
    const [services, setServices] = useState(allServices)
    const [mobileServices, setMobileServices] = useState(allServices.slice(0, 12))
    const [isDropdownOpen, setIsDropdownOpen] = useState(false)

    const handleTabClick = (tab) => {
        setSelectedTab(tab)
        setIsDropdownOpen(false)

        if (tab === 'All Connectors') {
            setServices(allServices)
            setMobileServices(allServices.slice(0, 12))
            return
        }

        const connector = INTEGRATION_SERVICES.find(
            (c) => c.connector === tab
        )

        if (!connector) return

        const sorted = [...connector.services].sort((a, b) =>
            a.name.localeCompare(b.name)
        )

        setServices(sorted)
        setMobileServices(sorted.slice(0, 12))
    }

    const loadMore = () => {
        setMobileServices((prev) =>
            prev.concat(services.slice(prev.length, prev.length + 12))
        )
    }

    return (
        <section className="integrations-section">
            <div className="integrations-card no-scrollbar">
                {/* Mobile dropdown */}
                <button
                    className="integrations-mobile-header"
                    onClick={() => setIsDropdownOpen((p) => !p)}
                >
                    {selectedTab}
                    <span className={`arrow ${isDropdownOpen ? 'open' : ''}`}><img noZoom src="/public/images/icons/arrow-down.svg" alt='Arrow down' className='arrow-down' /></span>
                </button>

                {/* Sidebar */}
                <aside
                    className={`integrations-sidebar ${isDropdownOpen ? 'open' : ''
                        }`}
                >
                    <button
                        className={`sidebar-item ${selectedTab === 'All Connectors' ? 'active' : ''
                            }`}
                        onClick={() => handleTabClick('All Connectors')}
                    >
                        All Connectors
                    </button>

                    {INTEGRATION_SERVICES.map((item) => (
                        <button
                            key={item.connector}
                            className={`sidebar-item ${selectedTab === item.connector ? 'active' : ''
                                }`}
                            onClick={() => handleTabClick(item.connector)}
                        >
                            {item.connector}
                        </button>
                    ))}
                </aside>

                {/* Desktop grid */}
                <div className="integrations-grid desktop">
                    {services.map((item) => (
                        <a
                            key={item.name}
                            href={item.link}
                            className="integration-card"
                        >
                            <img noZoom src={item.image} alt={item.name} />
                            <span>{item.name}</span>
                        </a>
                    ))}
                </div>

                {/* Mobile grid */}
                <div className="integrations-grid mobile">
                    {mobileServices.map((item) => (
                        <a
                            key={item.name}
                            href={item.link}
                            className="integration-card"
                        >
                            <img noZoom src={item.image} alt={item.name} />
                            <span>{item.name}</span>
                        </a>
                    ))}

                    {services.length > mobileServices.length && (
                        <button className="load-more" onClick={loadMore}>
                            Load More
                        </button>
                    )}
                </div>
            </div>
        </section>
    )
}

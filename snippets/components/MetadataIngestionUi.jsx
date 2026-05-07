export const MetadataIngestionUi = ({ connector, selectServicePath, addNewServicePath, serviceConnectionPath }) => {
  return (
  <>
    <p>
      To ingest metadata from your sources, you need to create a service connection.
      The service connects your source system with OpenMetadata. Once you create
      a service, you can use it to configure your ingestion workflows.<br/>
      <br/>
      To create a service connection and ingest your metadata, follow the steps below:
    </p>
      <Steps>
      <Step title="Select the Service">
        <ol>
          <li>
            On the left navigation bar, click <strong>Settings</strong>.
          </li>
          <li>
            On the next page, click <strong>Services</strong>, and then select the service.
            <img src="/public/images/connectors/visit-services-page.png" alt="Visit Services Page" />
          </li>
        </ol>
      </Step>

      <Step title="Create a New Service">
        To add a new service connection, click <strong>Add New Service</strong>.
        <img src="/public/images/connectors/create-new-service.png" alt="Create a new Service" />
      </Step>

      <Step title="Select the Connector">
        Select <strong>{connector}</strong> as the service type and click <strong>Next</strong>.

        {selectServicePath && <img src={selectServicePath} alt="Select Service" />}
      </Step>

      <Step title="Name and Describe the Service">
        Enter a unique <strong>Service Name</strong> and <strong>Description</strong>.
        <ul>
         <li><strong>Service Name</strong>: OpenMetadata identifies services by their service name. Enter a name that distinguishes this deployment from other services, including other {connector} services you are ingesting metadata from.</li>
        </ul>

        <Note>
          The service name cannot be changed after it is set.
       </Note>

        {addNewServicePath && <img src={addNewServicePath} alt="Add New Service" />}
      </Step>

      <Step title="Configure the Service Connection">
        Set up the connection settings required for {connector} to set up the service and start ingesting metadata from your sources. The right-hand panel displays help documentation for the selected connection type in the product UI.
        {serviceConnectionPath && <img src={serviceConnectionPath} alt="Configure Service connection" />}
      </Step>
    </Steps>
  </>
  );
};

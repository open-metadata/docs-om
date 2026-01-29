export const MetadataIngestionUi = ({ connector, selectServicePath, addNewServicePath, serviceConnectionPath }) => {
  return (
    <Steps>
      <Step title="Visit the Services Page">
        Click `Settings` in the side navigation bar and then `Services`.

        The first step is to ingest the metadata from your sources. To do that, you first need to create a Service connection first.

        This Service will be the bridge between OpenMetadata and your source system.

        Once a Service is created, it can be used to configure your ingestion workflows.

        <img src="/public/images/connectors/visit-services-page.png" alt="Visit Services Page" />
      </Step>

      <Step title="Create a New Service">
        Click on _Add New Service_ to start the Service creation.

        <img src="/public/images/connectors/create-new-service.png" alt="Create a new Service" />
      </Step>

      <Step title="Select the Service Type">
        Select {connector} as the Service type and click _Next_.

        {selectServicePath && <img src={selectServicePath} alt="Select Service" />}
      </Step>

      <Step title="Name and Describe your Service">
        Provide a name and description for your Service.

        <h4>Service Name</h4>

        OpenMetadata uniquely identifies Services by their **Service Name**. Provide
        a name that distinguishes your deployment from other Services, including
        the other {connector} Services that you might be ingesting metadata
        from.

        Note that when the name is set, it cannot be changed.

        {addNewServicePath && <img src={addNewServicePath} alt="Add New Service" />}
      </Step>

      <Step title="Configure the Service Connection">
        In this step, we will configure the connection settings required for {connector}.

        Please follow the instructions below to properly configure the Service to read from your sources. You will also find
        helper documentation on the right-hand side panel in the UI.

        {serviceConnectionPath && <img src={serviceConnectionPath} alt="Configure Service connection" />}
      </Step>
    </Steps>
  );
};
